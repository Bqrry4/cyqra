module cyqra::sema::types;

faultdef INVALID_TYPE;

enum Type
{
	UNIT,
	ANY,
	INT,
	FLOAT,
	BOOL,
	STRING,
	LIST,
	RECORD,
	FN,
	STREAM,
	ATOM
}

fn bool compatibility(Type left, Type right)
{
	switch {
		case left  == ANY:
		case right == ANY:
			return true;
		default: return left == right;
	}
}

fn Type? resolve(String type)
{
	switch (type) {
		case "int": return Type.INT;
		case "float": return Type.FLOAT;
		case "bool": return Type.BOOL;
		case "string": return Type.STRING;
		case "any": return Type.ANY;
	}
	return INVALID_TYPE~;
}
