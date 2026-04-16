module cyqra::interpreter;
import std::io;
import std::math;
import std::collections::list;
import std::os::process;

import cyqra::parser::ast;
import utils;

faultdef UNSUPORTED_OP,
		NOT_A_FUNCTION,
		INVALID_ARGS_COUNT,
		IDENTIFIER_NOT_FOUND,
		//! Temporary solution for the return from functions using faults
		RETURN_STATEMENT;

struct Interpreter
{
	Allocator allocator;
	Scope* scope;

	//! temporary solution
	Value return_value;
	String identifier;
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
	alloc::free(self.allocator, self.scope);
}

fn void Interpreter.interpret(&self, Ast ast)
{
	Value last = value::UNIT;
	foreach (expr: ast.expressions) {
		// if (catch @try(last, self.eval(expr))) {
		// 	io::printn("Error eval");	
		// }
		last = self.eval(expr)!!;
	}
	if (last.kind != UNIT) {
		String s_val = last.to_string(self.allocator);
		io::printn(s_val);
		s_val.free(self.allocator);
	}
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
		case RETURN:
			return self.eval_return(&expr.ret);
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
			Value? val = self.scope.get(expr.token.slice);
			if (catch val) {
				self.identifier = expr.token.slice;
				return IDENTIFIER_NOT_FOUND~;
			}
			return val;
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
		defer {
			local_scope.free();
			alloc::free(self.allocator, local_scope);
		}
	}
	
	self.scope = local_scope;
	defer {
		self.scope = local_scope.parent.ptr;
	}
	
	Value last = value::UNIT;
	foreach (stmt: expr.stmts) {
		last = self.eval(stmt)!;
	}

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


fn Value? Interpreter.eval_call(&self, Call* expr)
{
	Value callee; 
    fault err = @catch(
		@try(callee, self.eval(expr.callee))
	);

    if (err && err != IDENTIFIER_NOT_FOUND) return err~;

	List{ Value } args; args.init(self.allocator, expr.args.size + 1);
    defer args.free();

	//@ Add dummy value for the external call
	args.push(value::UNIT);
	foreach (arg_expr: expr.args) {
		args.push(self.eval(arg_expr)!);
	}

    if (err == IDENTIFIER_NOT_FOUND) {
		args[0] = value::_string(self.identifier);
		return self.call_external(args.array_view());
	}
	
	if (!callee.is_fn()) return NOT_A_FUNCTION~;
	return self.call_fn(callee._fn, args.array_view()[1..]);
}


fn Value? Interpreter.call_fn(&self, Fn _fn, Value[] args)
{	
	Scope* fn_scope = scope::new_ref(self.allocator, nullable::value(self.scope));
	defer fn_scope.free();

	if (_fn.params.len() != args.len) {
		return INVALID_ARGS_COUNT~;
	}
	foreach (i, arg: args) {
		fn_scope.set(_fn.params[i], arg);
	}
	Value returned = value::UNIT;
	if (catch err = @try(returned, self.eval_block(_fn.body, nullable::value(fn_scope)))) {
		if (err == RETURN_STATEMENT) {
			return self.return_value;
		}
	}
	return returned;
}

fn Value? Interpreter.call_external(&self, Value[] cmd_args)
{
	String[] cmd_line = alloc::new_array(self.allocator, String, cmd_args.len);
	defer alloc::free(self.allocator, cmd_line);

	foreach(i, arg: cmd_args) {
		cmd_line[i] = arg.to_string(self.allocator);
	}
	defer foreach (arg: cmd_line) {
		arg.free(self.allocator);
	}

	char[] buffer;
	int? id = process::run(cmd_line, INHERIT_STDIO);

	return value::UNIT;
}

fn Value? Interpreter.eval_return(&self, Return* expr)
{
	self.return_value = value::UNIT;
	if(!expr.value.is_null()) {
		self.return_value = self.eval(expr.value.ptr)!;
	}
	return RETURN_STATEMENT~;
}
