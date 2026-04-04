module cyqra::parser::namespace;
import std::collections::set;
import utils::nullable;

struct Namespace
{
	Nullable{ Namespace* } parent;
	HashSet{ String } set;
}

<* The returned ref must be freed explicitly *>
fn Namespace* new_ref(Allocator allocator, Nullable{ Namespace* } parent = nullable::NULL)
{
	HashSet{ String } set;
	set.init(allocator);

	return alloc::new(allocator, Namespace, {
		.parent = parent,
		.set = set
	});
}

fn void Namespace.free(&self)
{
	self.set.free();
}

fn void Namespace.add(&self, String value) => self.set.add(value);
fn bool Namespace.has(&self, String value)
{
	bool is_defined = self.set.contains(value);
	if (!is_defined && !self.parent.is_null()) {
		is_defined = self.parent.ptr.has(value);
	}
	return is_defined;
}
