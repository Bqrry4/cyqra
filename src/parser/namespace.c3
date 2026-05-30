module cyqra::parser::namespace;
import std::collections::list;
import std::collections::map;
import utils::nullable;

import cyqra::parser::ast::expr;
import cyqra::parser::varpool;

alias Frame = HashMap{ String, VarID };

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
	HashMap{ String, VarID } frame;
	frame.init(self.alloc);
	self.frames.push(frame);
}

fn void Namespace.leave(&self)
{
	self.frames.pop()!!.free();
}

fn void Namespace.add(&self, String name, VarID id) => self.frames[^1].set(name, id);
fn VarID? Namespace.get(&self, String name)
{
	foreach_r (frame: self.frames) {
		if (try id = frame.get(name)) return id;
	}
	return NOT_FOUND~;
}
