module cyqra::parser::namespace;
import std::collections::set;
import utils::nullable;

struct Namespace
{
	Nullable{ Namespace* } parent;
	HashSet{ String } set;
}

<* The returned ref must be freed explicitly *>
fn Namespace* new_ref(Allocator alloc, Nullable{ Namespace* } parent = nullable::NULL)
{
	HashSet{ String } set;
	set.init(alloc);

	return alloc::new(alloc, Namespace, {
		.parent = parent,
		.set = set
	});
}


<*
	Frees the instance AND the added values.
*>
fn void Namespace.free(&self, Allocator alloc)
{
	self.set.@each(;value) {
		value.free(alloc);
	};
	self.set.free();
}

<*
	!Gets ownership over the added value.
*>
fn void Namespace.add(&self, String value) => self.set.add(value);
fn bool Namespace.has(&self, String value)
{
	bool is_defined = self.set.contains(value);
	if (!is_defined && !self.parent.is_null()) {
		is_defined = self.parent.ptr.has(value);
	}
	return is_defined;
}
