module cyqra::ir::insn;
import cyqra::ir::reg_alloc;

enum Opcode : char (String name, InstructionFormat format) {
	HALT  {"halt", Z},
 // MOVE  {"move", R},  //rd := rsa
	LOAD {"load", U},
	LOADK {"loadk", U}, //rd := imm
	STORE {"store", S},    //imm := rd
	JMP   {"jmp", U},   //rd := pc + 4, pc := pc + imm 
	
	INFIX {"infix", I}, //{I} rd := rd [imm] rs1
	// LAUNCH,
	// SPAWN,
	RETURN {"ret", U}
}

enum InstructionFormat {
	Z, R, I, U, S
}

struct Instruction {
	Opcode op;
	union {
		Rfmt r;
		Ifmt i;
		Ufmt u;
		Sfmt s;
	}
}

/* Instruction formats */
bitstruct Rfmt : ulong
{
	RegId rd  : 8..15;
	RegId rsa : 16..23;
	RegId rsb : 24..31;
}
bitstruct Ifmt : ulong
{
	RegId rd  : 8..15;
	RegId rs  : 16..23;
	ichar imm : 24..31;
}
bitstruct Ufmt : ulong
{
	RegId rd  : 8..15;
	short imm : 16..31;
}
bitstruct Sfmt : ulong
{
	short imm : 8..23;
	RegId rs  : 24..31;
}
macro Instruction ret(RegId rd) => {
	.op = RETURN,
	.u = {
		.rd = rd
	}
};
