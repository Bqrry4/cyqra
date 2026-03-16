module cyqra::interpreter;
import std::io;

import cyqra::parser::ast;

enum ValueKind
{
	UNIT,
	INT,
	FLOAT,
	STRING,	
}

struct Value
{
	ValueKind kind;
	union {
		long _int;
		double _float;
		String _string;
	}
}

fn void Value.print(&self)
{
	switch(self.kind) {
		case INT: io::printn(self._int);
		case FLOAT: io::printn(self._float);
		default:
	}
}

struct Interpreter
{
	Ast ast;
}

fn Interpreter new(
	Ast ast
)
{
	return {
		.ast = ast,
	};
}

fn void Interpreter.interpret(&self)
{
	foreach (expr: self.ast.expressions) {
		Value val = expr.eval();
		val.print();		
	}
}

fn Value Expr.eval(&self)
{
	switch (self.kind) {
		case PRIMARY:
			return self.primary.eval();			
		// case PREFIX:
		// 	expr.prefix.eval();
		// case POSTFIX:
		// 	expr.postfix.eval();
		case INFIX:
			return self.infix.eval();
		// case CALL:
		// 	expr.call.eval();
		// case INDEX:
		// 	expr.index.eval();
		// case BINDING:
		// 	expr.binding.eval();
		// case BLOCK:
		// 	expr.block.eval();
		// case FUNCTION:
		// 	expr.block.eval();
		default: io::printn("not implemented");
	}
	return {
		.kind = UNIT
	};
}

fn Value Primary.eval(&self)
{
	switch (self.token.kind) {
		case INTEGER: return {
			.kind = INT,
			._int = self.token.slice.to_long()!!
		};
		case FLOAT: return {
			.kind = FLOAT,
			._float = self.token.slice.to_double()!!
		};
		case IDENTIFIER:
		default: unreachable("Unreachable reached in primary eval"); 
	}
}

fn Value Infix.eval(&self)
{
	Value lhs_v = self.lhs.eval();
	Value rhs_v = self.rhs.eval();

	switch (self.op) {
		case PLUS:
			if (lhs_v.kind == INT && rhs_v.kind == INT) {
                return {
					.kind = INT,
					._int = lhs_v._int + rhs_v._int,
				};
            }
            unreachable("invalid operands for +");
		case MINUS:
		case STAR:
		default: unreachable("Unreacahble reached in infix eval");	
	}		
}
