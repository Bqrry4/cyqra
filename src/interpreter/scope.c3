module cyqra::interpreter::scope;
import std::collections::map;
import utils::nullable;

import cyqra::interpreter::value;

struct Scope
{
	Allocator allocator;
	HashMap{ String, Value } bindings;
	Nullable{ Scope* } parent;	
}

<* The returned pointer from this function must be freed manually *>
fn Scope* new_ref(Allocator allocator, Nullable{ Scope* } parent = nullable::NULL)
{
	HashMap{ String, Value } bindings;	
	bindings.init(allocator);
	
	return allocator::new(allocator, Scope, {
		.allocator = allocator,
		.bindings  = bindings,
		.parent = parent
	});
}

fn void Scope.free(&self)
{
	self.bindings.free();
}

fn Value? Scope.get(&self, String ident) @operator([])
{
	Value? val = self.bindings[ident];
	if (!(@ok(val) || self.parent.is_null())) {
		val = self.parent.ptr.get(ident);
	}
    return val;
}

fn void Scope.set(&self, String ident, Value value) @operator([]=)
{
	self.bindings[ident] = value;
}
