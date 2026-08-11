module cyqra::ir::reg_alloc;
import std::collections::list;

alias RegId = char;

struct RegisterAllocator {
	char head;
	char max_registers;
}

fn void RegisterAllocator.free(&self, char cnt = 1)
{
	self.head -= cnt;
}

fn RegId RegisterAllocator.reserve(&self) => self.head++;

fn RegId RegisterAllocator.pop(&self) => --self.head;
fn RegId RegisterAllocator.top(&self) => self.head - 1;
