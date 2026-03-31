module utils::result <Value, Error>;

struct Result 
{
	bool is_error;
	union {
		Value value;
		Error error;
	}
}

macro Result value(Value value) => {
	.is_error = false,
	.value = value
};
macro Result error(Error error) => {
	.is_error = true,
	.error = error
};

macro @try(#v, #expr)
{
	var res = #expr;
	if (res.is_error) return self;
	#v = self.value;
}
