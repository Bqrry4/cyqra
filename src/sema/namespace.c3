module cyqra::sema::namespace;
import std::collections::list;
import std::collections::map;
import utils::nullable;

import cyqra::ast::expr;
import cyqra::sema::symbol_pool;

alias Frame = HashMap{ String, SymbolID };

<* Works over borrowed values *>
struct Namespace
{
	Allocator alloc;
	List{ Frame } frames;
}

fn Namespace new(Allocator alloc)
{
	List{ Frame } frames;
	frames.init(alloc);
	return {
		.alloc = alloc,
		.frames = frames
	};
}

fn void Namespace.free(&self)
{
	foreach (&frame: self.frames) {
		frame.free();
	}
	self.frames.free();
}

fn void Namespace.enter(&self)
{
	HashMap{ String, SymbolID } frame;
	frame.init(self.alloc);
	self.frames.push(frame);
}

fn void Namespace.leave(&self)
{
	self.frames.pop()!!.free();
}

fn void Namespace.add(&self, String name, SymbolID id) => self.frames[^1].set(name, id);
fn SymbolID? Namespace.get(&self, String name)
{
	foreach_r (&frame: self.frames) {
		if (try id = frame.get(name)) return id;
	}
	return NOT_FOUND~;
}
