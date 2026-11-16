module cyqra::vm;
import std::collections::list;
import cyqra::value;
import cyqra::ir::insn;
import std::io;

struct Vm {
	Value[] k;
	<* temp regs *>
	Value[] t;
	<* saved regs/stack *>
	Value[] s;
 }

fn Vm new(Value[] consts) => {
	.t = mem::new_array(Value, 256),
	.s = mem::new_array(Value, 16),
	.k = consts
};

fn void Vm.free(&self) { mem::free(self.t); }

fn void Vm.run(&self, Instruction[] code)
{
	Instruction* ip = code;
	fault trap = @catch(@dispatch(ip, self){});
}

fn void Vm.dump(&self)
{
	io::printn(self.k);
	io::printn(self.t);
}
