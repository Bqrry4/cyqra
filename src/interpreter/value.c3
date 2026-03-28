module cyqra::interpreter::value;
import std::io;
import std::collections::pair;
import std::collections::list;

import cyqra::parser::ast;

enum ValueKind
{
	UNIT,
	INT,
	FLOAT,
	STRING,
	FUNCTION	
}

struct Fn {
	List{ String } params;
	Block* body;
}

struct Value
{
	ValueKind kind;
	union {
		long _int;
		double _float;
		String _string;
		Fn _fn;
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
	}
}
