module cyqra::interpreter::scope @if(false);
import std::collections::map;
import utils::nullable;

import cyqra::interpreter::value;
import cyqra::sema::symbol_pool;

struct Scope
{
	Allocator allocator;
	HashMap{ uint, Value* } bindings;
	Nullable{ Scope* } parent;	
}

<* The returned ref must be freed explicitly *>
fn Scope* new_ref(Allocator allocator, Nullable{ Scope* } parent = nullable::NULL)
{
	HashMap{ uint, Value* } bindings;	
	bindings.init(allocator);
	
	return alloc::new(allocator, Scope, {
		.allocator = allocator,
		.bindings  = bindings,
		.parent = parent
	});
}

fn void Scope.free(&self)
{
	self.bindings.free();
}

fn Value*? Scope.get(&self, SymbolID id) {
	Value*? val = self.bindings.get((uint)id);
	if (!(@ok(val) || self.parent.is_null())) {
		val = self.parent.ptr.get(id);
	}
    return val;
}

fn void Scope.set(&self, SymbolID id, Value* value) @operator([]=)
{
	self.bindings[(uint)id] = value;
}
