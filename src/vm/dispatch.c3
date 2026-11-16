module cyqra::vm;
import cyqra::ir::insn;
import cyqra::parser::op;
import cyqra::value;
import std::io;

faultdef INVALID_INSTRUCTION, HALT;

alias Handler = fn void?(Instruction* ip, Vm* vm);

const Handler[] INSTRUCTIONS = {
	[Opcode.HALT] = &halt,
	[Opcode.LOADK] = &loadk,
	// [Opcode.LOADS] = &loads,
	[Opcode.INFIX] = &infix,
};

macro @next(ip, vm; @body) { @dispatch(++ip, vm) { @body(); }!; }
macro @dispatch(ip, vm; @body)
{	
	@body();
	INSTRUCTIONS[ip.op](ip, vm)!;
}

fn void? halt(Instruction* ip, Vm* ctx) => HALT~;

fn void? loadk(Instruction* ip, Vm* ctx) { @next(ip, ctx)
{
	Ufmt* u = &ip.u;
	io::printn("loadk");
	io::printn(ip);
	io::printn(u.rd);
	ctx.t[u.rd] = ctx.k[u.imm];
}!;}

/*

TODO: an instruction could trap!

*/
fn void? infix(Instruction* ip, Vm* ctx) { @next(ip, ctx)
{
	Ifmt* i = &ip.i;

	Value lhs = ctx.t[i.rd];
	Value rhs = ctx.t[i.rs];
	switch ((Operator)i.imm) {
	case ADD:
		ctx.t[i.rd] = *value::add(&lhs, &rhs)!!;
	case SUB:
		ctx.t[i.rd] = *value::sub(&lhs, &rhs)!!;
	case MUL:
		ctx.t[i.rd] = *value::mul(&lhs, &rhs)!!;
	case DIV:
		ctx.t[i.rd] = *value::div(&lhs, &rhs)!!;
	case FLOOR_DIV:
		ctx.t[i.rd] = *value::floor_div(&lhs, &rhs)!!;
	case MOD:
		ctx.t[i.rd] = *value::mod(&lhs, &rhs)!!;
	case POW:
		ctx.t[i.rd] = *value::pow(&lhs, &rhs)!!;
	default:
		return INVALID_INSTRUCTION~;
	}
}!;}

//         case ADD: return add(lhs, rhs);
//         case SUB: return sub(lhs, rhs);
//         case MUL: return mul(lhs, rhs);
//         case DIV: return div(lhs, rhs);
//         case FLOOR_DIV: return floor_div(lhs, rhs);
//         case MOD: return mod(lhs, rhs);
//         case POW: return pow(lhs, rhs);
//
// fn void loads(Instruction* ip, Vm* ctx) => @dispatch(ip, ctx)
// {
// 	Ufmt* u = &ip.u;
// 	ctx.t[u.rd] = ctx.k[u.imm];
// }


