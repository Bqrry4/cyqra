module utils::nullable <Type>;

struct Nullable
{
	Type ptr;
}

fn bool Nullable.is_null(self)
{
	return self.ptr == null;
}

const Nullable NULL = { null };

fn Nullable value(Type ptr) =>{
	.ptr = ptr
};
