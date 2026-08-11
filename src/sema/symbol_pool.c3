module cyqra::sema::symbol_pool;
import std::collections::list;
import std::io;

import cyqra::sema::types;

typedef SymbolID = uint;
const SymbolID INVALID_SYMBOL = (SymbolID)uint::max;

struct FnDef
{
	List{ Type } formals_t;
	Type ret_type;
}

struct SymbolDef
{
	Type type;
	String name;
	union {
		FnDef fn_def;
	}
}

struct SymbolPool
{
	Allocator alloc;
	List{ SymbolDef* } defs;
}

fn SymbolPool new(Allocator alloc)
{
	List{ SymbolDef* } defs;
	defs.init(alloc);
	return {
		.alloc = alloc,
		.defs = defs
	};
}

fn void SymbolPool.free(&self)
{
    foreach (def: self.defs) {
		def.name.free(self.alloc);
		// if (def.type == Type.FN) {
		// 	def.fn_def.formals.free();
		// }
		alloc::free(self.alloc, def);
	}
    self.defs.free();
}

<*
	@param [own] name
*>
macro SymbolID SymbolPool.bind(&self, Type type, String name, #body = {}) @safemacro
{
	io::printn(name);
	SymbolDef* def = alloc::new(self.alloc, SymbolDef, {
		type,
		name.copy(self.alloc),
		#body
	});
    SymbolID id = (SymbolID)self.defs.len();

	self.defs.push(def);
	return id;
}

fn String SymbolPool.name_of(&self, SymbolID id) => self.defs[(sz)id].name;
fn SymbolDef* SymbolPool.def_of(&self, SymbolID id) => self.defs[(sz)id];
