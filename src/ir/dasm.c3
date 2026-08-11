module cyqra::ir::dasm;
import cyqra::ir::insn;
import std::io;
import std::collections::list;

fn void dissasembly(List{ Instruction } code)
{
	foreach (i: code) {
		dasm_instruction(i);		
	}
}

fn void dasm_instruction(Instruction i) @local
{
	io::printf(i.op.name);
	switch (i.op.format) {
		case R:
			io::printfn(" %%%d, %%%d, %%%d",
				i.r.rd, i.r.rsa, i.r.rsb
			);
		case I:
			io::printfn(" %%%d, %%%d, %d",
				i.i.rd, i.i.rs, i.i.imm
			);
		case U:
			io::printfn(" %%%d, %d",
				i.u.rd, i.u.imm
			);
		case S:
			io::printfn(" %d, %%%d",
				i.s.imm, i.s.rs
			);
		case Z:
		default:
	}
}
