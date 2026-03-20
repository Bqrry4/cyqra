module cyqra::interpreter::value;
import std::io;
import std::collections::pair;

enum ValueKind
{
	UNIT,
	INT,
	FLOAT,
	STRING,	
}

struct Value
{
	ValueKind kind;
	union {
		long _int;
		double _float;
		String _string;
	}
}

const Value UNIT = {
	.kind = UNIT
};

fn Pair{ Value, Value } coerce(Value rhs, Value lhs)
{
	return { rhs, lhs };
}

fn String Value.to_string(&self, Allocator allocator)
{
	switch (self.kind) {
		case UNIT: return "";
		case STRING: return self._string;
		case INT: return string::format(allocator, "%d", self._int);
		case FLOAT: return string::format(allocator, "%.16f", self._float);
	}
}

fn void Value.print(&self)
{
	switch(self.kind) {
		case INT: io::printn(self._int);
		case FLOAT: io::printn(self._float);
		case STRING: io::printn(self._string);
		default:
	}
}

