module cyqra::interpreter;
import std::io;
import std::math;

import cyqra::parser::ast;
import utils;

struct Interpreter
{
	Allocator allocator;

	Scope* scope;
}

fn Interpreter new(
	Allocator allocator
)
{
	Scope* scope = scope::new_ref(allocator);
	return {
		.allocator = allocator,
		.scope = scope
	};
}

fn void Interpreter.free(&self)
{
	self.scope.free();
	allocator::free(self.allocator, self.scope);
}

fn void Interpreter.interpret(&self, Ast ast)
{
	Value last = value::UNIT;
	foreach (expr: ast.expressions) {
		if (catch @try(last, self.eval(expr))) {
			io::printn("Error eval");	
		}
	}
	String s_val = last.to_string(self.allocator);
	io::printn(s_val);
	s_val.free(self.allocator);	
}

fn Value? Interpreter.eval(&self, Expr* expr)
{
	switch (expr.kind) {
		case PRIMARY:
			return self.eval_primary(&expr.primary);			
		case STRING:
			return self.eval_string(&expr.string);
		// case PREFIX:
		// 	expr.prefix.eval();
		// case POSTFIX:
		// 	expr.postfix.eval();
		case INFIX:
			return self.eval_infix(&expr.infix)!;
	// case CALL:
		// 	expr.call.eval();
		// case INDEX:
		// 	expr.index.eval();
		// 
		case BINDING:
			return self.eval_binding(&expr.binding);
		case BLOCK:
			return self.eval_block(&expr.block);
		// case FUNCTION:
		// 	expr.block.eval();
		default: io::printn("not implemented");
	}
	return value::UNIT;
}

fn Value? Interpreter.eval_primary(&self, Primary* expr)
{
	switch (expr.token.kind) {
		case INTEGER: return {
			.kind = INT,
			._int = expr.token.slice.to_long()!
		};
		case FLOAT: return {
			.kind = FLOAT,
			._float = expr.token.slice.to_double()!
		};
		case IDENTIFIER:
			return self.scope.get(expr.token.slice)!;
		default: unreachable("Unreachable reached in primary eval"); 
	}
}

fn Value? Interpreter.eval_string(&self, StringLiteral* expr)
{
	DString dstring = (DString){}.init(self.allocator);

	foreach (part: expr.parts) {
		switch (part.kind) {
			case TEXT:
				dstring.append(part.text);
			case INTERP:
				Value val = self.eval(part.interp)!;
				dstring.append(val.to_string(self.allocator));			
		}
	}

	String result = dstring.copy_str(self.allocator);
	dstring.free();
	
	return {
		.kind = STRING,
		._string = result
	};
}


faultdef UNSUPORTED_OP;

fn Value? Interpreter.eval_infix(&self, Infix* expr)
{
	Value lhs_v = self.eval(expr.lhs)!;
	Value rhs_v = self.eval(expr.rhs)!;

	if (lhs_v.kind != rhs_v.kind) {
		value::coerce(lhs_v, rhs_v)!.unpack(&lhs_v, &rhs_v);
	}

	switch (expr.op) {
		case PLUS: switch (lhs_v.kind) {
			case INT:
				return value::_int(lhs_v._int + rhs_v._int);
			case FLOAT:
				return value::_float(lhs_v._float + rhs_v._float);
			default: return UNSUPORTED_OP~;
		}
		case MINUS: switch(lhs_v.kind) {
			case INT:
				return value::_int(lhs_v._int - rhs_v._int);
			case FLOAT:
				return value::_float(lhs_v._float - rhs_v._float);
			default: return UNSUPORTED_OP~;
		}
		case STAR: switch(lhs_v.kind) {
			case INT:
				return value::_int(lhs_v._int * rhs_v._int);
			case FLOAT:
				return value::_float(lhs_v._float * rhs_v._float);
			default: return UNSUPORTED_OP~;
		}
		case STAR_STAR: switch(lhs_v.kind) {
			case INT:
				return value::_float(math::pow((int)lhs_v._int, (int)rhs_v._int));
			case FLOAT:
				return value::_float(math::pow(lhs_v._float, rhs_v._float));
			default: return UNSUPORTED_OP~;
		}
		case SLASH: switch(lhs_v.kind) {
			case INT:
				return value::_float(lhs_v.as_float()._float / rhs_v._int);
			case FLOAT:
				return value::_float(lhs_v._float / rhs_v._float);
			default: return UNSUPORTED_OP~;
		}
		case SLASH_SLASH: switch(lhs_v.kind) {
			case INT:
				return value::_int(lhs_v._int / rhs_v._int);
			case FLOAT:
				return value::_float(lhs_v._float - rhs_v._float);
			default: return UNSUPORTED_OP~;
		}
		case PERCENT: switch(lhs_v.kind) {
			case INT:
				return value::_int(lhs_v._int % rhs_v._int);
			case FLOAT:
				return value::_float(lhs_v._float - math::floor(lhs_v._float / rhs_v._float) * rhs_v._float);
			default: return UNSUPORTED_OP~;
		}
		default: unreachable("Unreacahble reached in infix eval");	
	}
	unreachable("Shouldnt trigger infix");
}

fn Value? Interpreter.eval_binding(&self, Binding* expr)
{
	Value value = self.eval(expr.value)!;

	switch (expr.type) {
		case LET:
		case MUT:
			self.scope.set(expr.identifier.slice, value);
		case ENV:	// os::set_var();
		default: unreachable("Not a binding keyword");			
	}
	

	return value::UNIT;
}

fn Value? Interpreter.eval_block(&self, Block* expr, Nullable{ Scope* } scope = nullable::NULL)
{
	Scope* local_scope = scope.ptr;
	if(scope.is_null()) {
		local_scope = scope::new_ref(self.allocator, nullable::value(self.scope));
		defer local_scope.free();
	}
	
	self.scope = local_scope;

	Value last = value::UNIT;
	foreach (stmt: expr.stmts) {
		last = self.eval(stmt)!;
	}

	self.scope = local_scope.parent.ptr;
	return last;	
}

fn Value? Interpreter.eval_fn(&self, Function* expr)
{
	return value::UNIT;
} 
