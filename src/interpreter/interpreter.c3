module cyqra::interpreter;
import std::io;
import std::math;

import cyqra::parser::ast;
import utils;

faultdef UNSUPORTED_OP;
faultdef NOT_A_FUNCTION;
faultdef INVALID_ARGS_COUNT;

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
		// if (catch @try(last, self.eval(expr))) {
			// io::printn("Error eval");	
		// }
		last = self.eval(expr)!!;
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
			return self.eval_infix(&expr.infix);
		case CALL:
	 		return self.eval_call(&expr.call);
		// case INDEX:
		// 	expr.index.eval();
		// 
		case BINDING:
			return self.eval_binding(&expr.binding);
		case BLOCK:
			return self.eval_block(&expr.block);
		case FUNCTION:
			return self.eval_fn(&expr.fun);
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

fn Value? Interpreter.eval_infix(&self, Infix* expr)
{
	Value lhs = self.eval(expr.lhs)!;
	Value rhs = self.eval(expr.rhs)!;

	if (lhs.kind != rhs.kind) {
		value::coerce(lhs, rhs)!.unpack(&lhs, &rhs);
	}

	switch (expr.op) {
		case PLUS: switch (lhs.kind) {
			case INT:
				return value::_int(lhs._int + rhs._int);
			case FLOAT:
				return value::_float(lhs._float + rhs._float);
			default: return UNSUPORTED_OP~;
		}
		case MINUS: switch(lhs.kind) {
			case INT:
				return value::_int(lhs._int - rhs._int);
			case FLOAT:
				return value::_float(lhs._float - rhs._float);
			default: return UNSUPORTED_OP~;
		}
		case STAR: switch(lhs.kind) {
			case INT:
				return value::_int(lhs._int * rhs._int);
			case FLOAT:
				return value::_float(lhs._float * rhs._float);
			default: return UNSUPORTED_OP~;
		}
		case STAR_STAR: switch(lhs.kind) {
			case INT:
				return value::_float(math::pow((int)lhs._int, (int)rhs._int));
			case FLOAT:
				return value::_float(math::pow(lhs._float, rhs._float));
			default: return UNSUPORTED_OP~;
		}
		case SLASH: switch(lhs.kind) {
			case INT:
				return value::_float(lhs.as_float()._float / rhs._int);
			case FLOAT:
				return value::_float(lhs._float / rhs._float);
			default: return UNSUPORTED_OP~;
		}
		case SLASH_SLASH: switch(lhs.kind) {
			case INT:
				return value::_int(lhs._int / rhs._int);
			case FLOAT:
				return value::_float(lhs._float - rhs._float);
			default: return UNSUPORTED_OP~;
		}
		case PERCENT: switch(lhs.kind) {
			case INT:
				return value::_int(lhs._int % rhs._int);
			case FLOAT:
				return value::_float(lhs._float - math::floor(lhs._float / rhs._float) * rhs._float);
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
		//! TODO env
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
	self.scope.set(expr.identifier.slice, {
		.kind = FUNCTION,
		._fn = {
			.params = expr.params,
			.body = &expr.body.block
		}
	});
	return value::UNIT;
} 

//! TODO split and use contracts
fn Value? Interpreter.eval_call(&self, Call* expr)
{
	if (try callee = self.eval(expr.callee)) {
		if (!callee.is_fn()) {
			return NOT_A_FUNCTION~;
		}
	
		Scope* fn_scope = scope::new_ref(self.allocator, nullable::value(self.scope));
		defer fn_scope.free();

		if (callee._fn.params.len() != expr.args.len()) {
			return INVALID_ARGS_COUNT~;
		}

		foreach (i, arg_expr: expr.args) {
			Value arg = self.eval(arg_expr)!;
			fn_scope.set(callee._fn.params[i], arg);
		}
		return self.eval_block(callee._fn.body, nullable::value(fn_scope));
	}
	//! TODO
	// prob a shell call
	
	return value::UNIT;
}
