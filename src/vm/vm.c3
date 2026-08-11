module cyqra::vm;
import cyqra::ir::insn;
import std::collections::list;
import cyqra::value;
import cyqra::parser::op;

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


fn void Vm.free(&self)
{
	mem::free(self.t);
}

fn void Vm.run(&self, Instruction[] code)
{
	Instruction* ip = code;
	while (true) {
		switch (ip.op) {
		case LOADK: self.loadk(&ip.u);
		// case LOADS: self.loads(&ip.u);
		case INFIX: self.infix(&ip.i);
		default:
		}	 
	}
}

fn void Vm.loadk(&self, Ufmt* u)
{
	self.t[u.rd] = self.k[u.imm];
}

fn void Vm.loads(&self, Ufmt* u)
{
	self.t[u.rd] = self.k[u.imm];
}

fn void Vm.infix(&self, Ifmt* i)
{
	Value lhs = self.t[i.rd];
	Value rhs = self.t[i.rs];
	switch ((Operator)i.imm) {
	case ADD:
		self.t[i.rd] = *value::add(&lhs, &rhs)!!;
	default:
	}
}
