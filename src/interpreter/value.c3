module cyqra::interpreter::value;
import std::io;
import std::collections::pair;
import std::collections::list;
import std::collections::map;
import std::math;

import cyqra::parser::op;
import cyqra::parser::ast;

faultdef UNSUPPORTED_OP;

enum ValueKind
{
	UNIT,
	INT,
	FLOAT,
	STRING,
	FUNCTION,
	ARRAY,
	RECORD
}

struct Fn
{
	List{ String } params;
	Block* body;
}

struct Array_v
{
	List{ Value } values;
}

struct Record_v
{
	HashMap{ String, Value } values;
}
struct Value
{
	ValueKind kind;
	union {
		long _int;
		double _float;
		String _string;
		Fn _fn;
		Array_v _array;
		Record_v _record;
	}
}

const Value UNIT = {
	.kind = UNIT
};

fn Value _int(long _int) => { .kind = INT, ._int = _int };
fn Value _float(double _float) => { .kind = FLOAT, ._float = _float };
fn Value _string(String _string) => { .kind = STRING, ._string = _string};

faultdef INCOMPATIBLE_TYPE;

fn Value? Value.as_int(&self)
{
	switch (self.kind) {
		case INT:
			return *self;
		case FLOAT:
			return _int((long)self._int);
		case STRING:
			return _int(self._string.to_long()!);
		default: return INCOMPATIBLE_TYPE~;
	}
}

fn Value? Value.as_float(&self)
{
	switch (self.kind) {
		case INT:
			return _float((double)self._int);
		case FLOAT:
			return *self;
		case STRING:
			return _float(self._string.to_double()!);
		default: return INCOMPATIBLE_TYPE~;
	}
}

fn bool Value.is_fn(&self) => self.kind == FUNCTION;

<* 
* float > int > string
*>
fn Pair{ Value, Value }? coerce(Value lhs, Value rhs)
{
	if (lhs.kind == FLOAT || rhs.kind == FLOAT) {
        return { lhs.as_float()!, rhs.as_float()! };
    }

	// string as maybe_float
	if ((lhs.kind == STRING && lhs._string.contains_char('.'))
		|| (rhs.kind == STRING && rhs._string.contains_char('.'))) {
		return { lhs.as_float()!, rhs.as_float()! };
	}

    if (lhs.kind == INT || rhs.kind == INT) {
        return { lhs.as_int()!, rhs.as_int()! };
    }

	return INCOMPATIBLE_TYPE~;
}

fn String Value.to_string(&self, Allocator allocator)
{
	switch (self.kind) {
		case UNIT: return string::format(allocator, "");
		case STRING: return string::format(allocator, "%s", self._string);
		case INT: return string::format(allocator, "%d", self._int);
		case FLOAT: return string::format(allocator, "%g", self._float);
		case FUNCTION: return string::format(allocator, "Function");
		case ARRAY: {
			DString str; str.init(allocator);
			defer str.free();

			str.append("[");
			foreach (i, val: self._array.values) {
				if (i > 0) str.append(", ");
				str.append(val.to_string(allocator));
			}
			str.append("]");

			return str.copy_str(allocator);
		} 
		case RECORD: {
			DString str; str.init(allocator);
			defer str.free();

			str.append("{");
			int i = 0;
			self._record.values.@each(; key, value) {
				if (i++ >0)	str.append(", ");
				str.append(key);
				str.append(": ");
				str.append(value.to_string(allocator));
			};
			str.append("}");

			return str.copy_str(allocator);
		}
	}
}

fn Value? add(Value lhs, Value rhs)
{
    switch (lhs.kind) {
        case INT: return value::_int(lhs._int + rhs._int);
        case FLOAT: return value::_float(lhs._float + rhs._float);
        // case STRING: return value::_string(string::join(lhs._string, rhs._string));
        default: return UNSUPPORTED_OP~;
    }
}

fn Value? sub(Value lhs, Value rhs)
{
    switch (lhs.kind) {
        case INT: return value::_int(lhs._int - rhs._int);
        case FLOAT: return value::_float(lhs._float - rhs._float);
        default: return UNSUPPORTED_OP~;
    }
}

fn Value? mul(Value lhs, Value rhs)
{
    switch (lhs.kind) {
        case INT: return value::_int(lhs._int * rhs._int);
        case FLOAT: return value::_float(lhs._float * rhs._float);
        default: return UNSUPPORTED_OP~;
    }
}

fn Value? div(Value lhs, Value rhs)
{
    switch (lhs.kind) {
        case INT: return value::_float((double)lhs._int / (double)rhs._int);
        case FLOAT: return value::_float(lhs._float / rhs._float);
        default: return UNSUPPORTED_OP~;
    }
}

fn Value? floor_div(Value lhs, Value rhs)
{
    switch (lhs.kind) {
        case INT: return value::_int(lhs._int / rhs._int);
        case FLOAT: return value::_float(math::floor(lhs._float / rhs._float));
        default: return UNSUPPORTED_OP~;
    }
}

fn Value? mod(Value lhs, Value rhs)
{
    switch (lhs.kind) {
        case INT: return value::_int(lhs._int % rhs._int);
        case FLOAT: return value::_float(
            lhs._float - math::floor(lhs._float / rhs._float) * rhs._float
        );
        default: return UNSUPPORTED_OP~;
    }
}

fn Value? pow(Value lhs, Value rhs)
{
    switch (lhs.kind) {
        case INT: return value::_float(math::pow((double)lhs._int, (double)rhs._int));
        case FLOAT: return value::_float(math::pow(lhs._float, rhs._float));
        default: return UNSUPPORTED_OP~;
    }
}
fn Value? apply_op(Operator op, Value lhs, Value rhs)
{
    if (lhs.kind != rhs.kind) {
        value::coerce(lhs, rhs)!.unpack(&lhs, &rhs);
    }
    switch (op) {
        case ADD: return add(lhs, rhs);
        case SUB: return sub(lhs, rhs);
        case MUL: return mul(lhs, rhs);
        case DIV: return div(lhs, rhs);
        case FLOOR_DIV: return floor_div(lhs, rhs);
        case MOD: return mod(lhs, rhs);
        case POW: return pow(lhs, rhs);
        default: return UNSUPPORTED_OP~;
    }
}

fn Value? pos(Value val)
{
    switch (val.kind) {
        case INT:
        case FLOAT: return val;
        default:    return UNSUPPORTED_OP~;
    }
}

fn Value? neg(Value val)
{
    switch (val.kind) {
        case INT:   return value::_int(-val._int);
        case FLOAT: return value::_float(-val._float);
        default:    return UNSUPPORTED_OP~;
    }
}

fn Value? not(Value val)
{
    switch (val.kind) {
        // case BOOL: return value::_bool(!val._bool);
        default:   return UNSUPPORTED_OP~;
    }
}
