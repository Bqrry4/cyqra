module cyqra::parser::varpool;

import std::collections::list;
import std::io;

typedef VarID = uint;

struct VarPool
{
	Allocator alloc;
	List{ String } names;
}

fn VarPool new(Allocator alloc)
{
	List{ String } names;
	names.init(alloc);
	return {
		.alloc = alloc,
		.names = names
	};
}

fn void VarPool.free(&self)
{
    foreach (name: self.names) name.free(self.alloc);
    self.names.free();
}

<*
	Owns a copy of @name after push.
*>
fn VarID VarPool.push(&self, String name)
{
    VarID id = (VarID)self.names.len();
	self.names.push(
		name.copy(self.alloc)
	);
    return id;
}

fn String VarPool.name_of(&self, VarID id)
{
    return self.names[(sz)id];
}
