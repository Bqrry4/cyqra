module cyqra::ir;
import cyqra::ast;
import cyqra::value;
import std::io;
import std::collections::list;


struct IRCode {
	List{ uint } stmts;
}

fn IRCode lower(Ast* ast)
{
	return {};
}

////////////////////////////

alias Bytes = List{ char };

struct Compiler {
	Bytes data;
	List{ Instruction } code;

	List{ Value } consts;
	RegisterAllocator t_alloc;
	RegisterAllocator s_alloc;

	short[] locals;
}

fn Compiler new()
{
	Bytes data; data.init(mem);
	List{ Instruction } code; code.init(mem);
	
	List{ Value } consts; consts.init(mem);
	return {
		.data = data,
		.code = code,
		.consts = consts,
		.locals = mem::new_array(short, 256)
	};
}

fn void Compiler.generate(&self, Ast* ast)
{
	self.compile(expr::@new(SEQUENCE, ast.expressions, {}));	
}

fn void Compiler.compile(&self, Expr* e)
{
	switch (e.kind) {
		case LITERAL: return self.compile_literal(&e.literal);
		case INFIX: return self.compile_infix(&e.infix);
		case SEQUENCE: return self.compile_sequence(&e.seq);
		case BINDING: return self.compile_binding(&e.bnd);
		case VARIABLE: return self.compile_var(&e.variable);
		default: io::printf("not implemented %s", e.kind);
	}
}

fn void Compiler.compile_literal(&self, Literal* l)
{
	switch (l.type) {
	case INT:
		self.consts.push(value::_int(l._int));

		Instruction i = {
			.op = LOADK,
			.u = {
				.rd = self.t_alloc.reserve(),
				.imm = (short)self.consts.len()
			}
		};
		self.code.push(i);
	case FLOAT:
		self.consts.push(value::_float(l._float));
	case STRING:
		switch (l._string.kind) {
		case STATIC:
			self.consts.push(value::_string(l._string.stc.copy(mem)));
		case DYNAMIC:

		}
	default: unreachable("Invalid literal type");
	}
}

fn void Compiler.compile_infix(&self, Infix* ifx)
{
	self.compile(ifx.lhs); //rd
	self.compile(ifx.rhs); //rs

	Instruction i = {
		.op = INFIX,
		.i = {
			.rs = self.t_alloc.pop(),		
			.rd = self.t_alloc.top(),
			.imm = (ichar)ifx.op.ordinal
		}
	};

	self.code.push(i);
}

fn void Compiler.compile_sequence(&self, Sequence* seq)
{
	foreach (s: seq) {
		self.compile(s);
	}
	self.code.push(insn::ret(self.t_alloc.top()));
}

fn void Compiler.compile_binding(&self, Binding* bnd)
{
	self.compile(bnd.value);
	short slot = self.s_alloc.reserve();
    self.locals[(sz)bnd.typed_name.ident.id] = slot;
	
	Instruction i = {
		.op = STORE,
		.s = {
			.imm = slot,
			.rs = self.t_alloc.top(),
		}
	};
	self.code.push(i);
}
fn void Compiler.compile_var(&self, Variable* variable)
{
	io::printn(self.locals[(sz)variable.id]);
	Instruction i = {
		.op = LOAD,
		.u = {
			.rd = self.t_alloc.reserve(),
			.imm = self.locals[(sz)variable.id],
		}
	};
	self.code.push(i);
}
