module cyqra::vm;
import std::collections::list;
import cyqra::value;
import cyqra::ir::insn;

struct Vm {
	List{ Value } k;
	<* temp regs *>
	Value[] t;
	<* saved regs/stack *>
	Value[] s;
 }

fn Vm new(List{ Value } consts) => {
	.t = mem::new_array(Value, 16),
	.s = mem::new_array(Value, 16),
	.k = consts
};

fn void Vm.free(&self) { mem::free(self.t); }

fn void Vm.run(&self, Instruction[] code)
{
	Instruction* ip = code;
	@dispatch(ip, self){};
}

