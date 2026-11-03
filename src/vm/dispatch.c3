module cyqra::vm;
import cyqra::ir::insn;
import cyqra::parser::op;
import cyqra::value;

alias Handler = fn void(Instruction* ip, Vm* vm);

const Handler[] INSTRUCTIONS = {
	[Opcode.LOADK] = &loadk,
	// [Opcode.LOADS] = &loads,
	[Opcode.INFIX] = &infix,
};

macro @dispatch(ip, vm; @body)
{
	@body();
	INSTRUCTIONS[(ip++).op](ip, vm);
}


fn void loadk(Instruction* ip, Vm* ctx) => @dispatch(ip, ctx)
{
	Ufmt* u = &ip.u;
	ctx.t[u.rd] = ctx.k[u.imm];
}

fn void infix(Instruction* ip, Vm* ctx) => @dispatch(ip, ctx)
{
	Ifmt* i = &ip.i;

	Value lhs = ctx.t[i.rd];
	Value rhs = ctx.t[i.rs];
	switch ((Operator)i.imm) {
	case ADD:
		ctx.t[i.rd] = *value::add(&lhs, &rhs)!!;
	default:
	}
}


// fn void loads(Instruction* ip, Vm* ctx) => @dispatch(ip, ctx)
// {
// 	Ufmt* u = &ip.u;
// 	ctx.t[u.rd] = ctx.k[u.imm];
// }


