module cyqra::interpreter;
import std::io;
import std::math;
import std::collections::list;
import std::collections::map;
import std::os::process;

import cyqra::lexer::token;
import cyqra::parser::ast;
import cyqra::diagnostic;
import utils;

faultdef
		RUNTIME_ERROR,
		UNSUPORTED_OP,
		NOT_A_FUNCTION,
		INVALID_ARGS_COUNT,
		IDENTIFIER_NOT_FOUND,
		//! Temporary solution for the return from functions using faults
		RETURN_STATEMENT;

struct Interpreter
{
	Allocator allocator;
	Scope* scope;

	Diagnostic* diagnostic;

	//! temporary solution
	Value return_value;
	String identifier;
}

fn Interpreter new(
	Allocator allocator,
	Diagnostic* diagnostic
){
	Scope* scope = scope::new_ref(allocator);
	return {
		.allocator = allocator,
		.scope = scope,
		.diagnostic = diagnostic
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
		if (catch err = @try(last, self.eval(expr))) {
			io::printn(self.diagnostic);
		}
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
		case PRIMARY: return self.eval_primary(expr);
		case STRINGLIT: return self.eval_string(expr);
		// case PREFIX: expr.prefix.eval();
		// case POSTFIX: expr.postfix.eval();
		case INFIX: return self.eval_infix(expr);
		case CALL: return self.eval_call(expr);
		case INDEX: return self.eval_index(expr);
		case BINDING: return self.eval_binding(expr);
		case BLOCK: return self.eval_block(&expr.block);
		case FUNCTION: return self.eval_fn(expr);
		case RETURN: return self.eval_return(expr);
		case ARRAY: return self.eval_array(expr);
		case RECORD: return self.eval_record(expr);
		default: io::printn("not implemented");
	}
	return value::UNIT;
}

fn Value? Interpreter.eval_primary(&self, Expr* expr)
{
	Primary* p = &expr.primary;

	String slice = p.token.span.slice;
	TokenKind kind = p.token.kind;
	switch (kind) {
		case INTEGER: return value::_int(slice.to_long()!!);
		case FLOAT: return value::_float(slice.to_double()!!);
		case IDENTIFIER: {
			Value? val = self.scope.get(slice);
			if (catch val) {
				self.identifier = slice;
				return IDENTIFIER_NOT_FOUND~;
			}
			return val;
		}
		
		default: unreachable("eval_primary: unexpected token kind '%s'", kind);
	}
}

fn Value? Interpreter.eval_string(&self, Expr* expr)
{
	StringLit* s = &expr.string;
	DString dstring = (DString){}.init(self.allocator);

	foreach (part: s.parts) {
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

fn Value? Interpreter.eval_infix(&self, Expr* expr)
{
	Infix* ifx = &expr.infix;
		
	Value lhs = self.eval(ifx.lhs)!;
	Value rhs = self.eval(ifx.rhs)!;

	if (lhs.kind != rhs.kind) {
		value::coerce(lhs, rhs)!.unpack(&lhs, &rhs);
	}

	switch (ifx.op) {
		case ADD: switch (lhs.kind) {
			case INT:
				return value::_int(lhs._int + rhs._int);
			case FLOAT:
				return value::_float(lhs._float + rhs._float);
			default: return UNSUPORTED_OP~;
		}
		case SUB: switch(lhs.kind) {
			case INT:
				return value::_int(lhs._int - rhs._int);
			case FLOAT:
				return value::_float(lhs._float - rhs._float);
			default: return UNSUPORTED_OP~;
		}
		case MUL: switch(lhs.kind) {
			case INT:
				return value::_int(lhs._int * rhs._int);
			case FLOAT:
				return value::_float(lhs._float * rhs._float);
			default: return UNSUPORTED_OP~;
		}
		case POW: switch(lhs.kind) {
			case INT:
				return value::_float(math::pow((int)lhs._int, (int)rhs._int));
			case FLOAT:
				return value::_float(math::pow(lhs._float, rhs._float));
			default: return UNSUPORTED_OP~;
		}
		case DIV: switch(lhs.kind) {
			case INT:
				return value::_float(lhs.as_float()._float / rhs._int);
			case FLOAT:
				return value::_float(lhs._float / rhs._float);
			default: return UNSUPORTED_OP~;
		}
		case FLOOR_DIV: switch(lhs.kind) {
			case INT:
				return value::_int(lhs._int / rhs._int);
			case FLOAT:
				return value::_float(lhs._float - rhs._float);
			default: return UNSUPORTED_OP~;
		}
		case MOD: switch(lhs.kind) {
			case INT:
				return value::_int(lhs._int % rhs._int);
			case FLOAT:
				return value::_float(lhs._float - math::floor(lhs._float / rhs._float) * rhs._float);
			default: return UNSUPORTED_OP~;
		}
		default: unreachable("Unreacahble reached in infix eval");	
	}
}

fn Value? Interpreter.eval_binding(&self, Expr* expr)
{
	Binding* bnd = &expr.binding;
	Value value = self.eval(bnd.value)!;

	switch (bnd.type) {
		case LET:
		case MUT:
			self.scope.set(bnd.identifier.span.slice, value);
		//! TODO env
		case ENV:	// os::set_var();
		default: unreachable("Not a binding keyword");			
	}
	return value::UNIT;
}

fn Value? Interpreter.eval_block(&self, Block* expr, Nullable{ Scope* } scope = nullable::NULL)
{
	// Block* blk = &expr.block;
	
	Scope* local_scope = scope.ptr;
	// Create an owned scope if not provided
	bool owned = scope.is_null();
	if (owned) {
		local_scope = scope::new_ref(
			self.allocator, nullable::value(self.scope)
		);	
	}
	defer if (owned) {
		local_scope.free();
		alloc::free(self.allocator, local_scope);
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

fn Value? Interpreter.eval_fn(&self, Expr* expr)
{
	Function* fun = &expr.fun;
	self.scope.set(fun.identifier.span.slice, {
		.kind = FUNCTION,
		._fn = {
			.params = fun.params,
			.body = &fun.body.block
		}
	});
	return value::UNIT;
} 


fn Value? Interpreter.eval_call(&self, Expr* expr)
{
	Call* call = &expr.call;
	Value callee; 
    fault err = @catch(
		@try(callee, self.eval(call.callee))
	);

    if (err && err != IDENTIFIER_NOT_FOUND) return err~;

	List{ Value } args; args.init(self.allocator, call.args.size + 1);
    defer args.free();

	//@ Add dummy value for the external call
	args.push(value::UNIT);
	foreach (arg_expr: call.args) {
		args.push(self.eval(arg_expr)!);
	}

    if (err == IDENTIFIER_NOT_FOUND) {
		args[0] = value::_string(self.identifier);
		Value? ret = self.call_external(args.array_view());
		if (catch err2 = ret) {
			self.diagnostic.error(call.callee.span, "command not found");
			return RUNTIME_ERROR~;
		}
		return ret;
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
	
	if (catch err = process::run(cmd_line, INHERIT_STDIO)) {
		//! It could fail from many reasons,
		// but assume Cmd not found,
		// as stdlib doesnt expose reasons yet
		if (err == process::FAILED_TO_START_PROCESS) {
			return RUNTIME_ERROR~;
		}
	}

	return value::UNIT;
}

fn Value? Interpreter.eval_return(&self, Expr* expr)
{
	Return* ret = &expr.ret;
	self.return_value = value::UNIT;
	if(!ret.value.is_null()) {
		self.return_value = self.eval(ret.value.ptr)!;
	}
	return RETURN_STATEMENT~;
}

fn Value? Interpreter.eval_array(&self, Expr* expr)
{
	Array* arr = &expr.array;

	List{ Value } values; values.init(self.allocator);
	foreach (expr_val : arr.init_values) {
		values.push(self.eval(expr_val)!);
	}
	return {
		.kind = ARRAY,
		._array = { values }
	};
}
fn Value? Interpreter.eval_record(&self, Expr* expr)
{
	Record* rec = &expr.record;
	HashMap{ String, Value } values; values.init(self.allocator);

	foreach (field : rec.fields) {
		//TODO: remake identifiers to a separate, non-primary struct
		String key;
		if (field.key.primary.token.kind == IDENTIFIER) {
			key = field.key.primary.token.span.slice.copy(self.allocator);
		} else {
			key = self.eval(field.key).to_string(self.allocator)!;
		}
		Value value = self.eval(field.value)!;
		values.set(key, value);
	}
	return {
		.kind = RECORD,
		._record = { values }
	};
}

fn Value? Interpreter.eval_index(&self, Expr* expr)
{
	Index* idx = &expr.index;
	Value index_v = self.eval(idx.index)!;
	Value object = self.eval(idx.object)!;
	switch (object.kind) {
		case ARRAY: {
			if (index_v.kind != INT) {
				self.diagnostic.error(idx.index.span, "provided value vas not an INT");
				return RUNTIME_ERROR~;
			}
			long index = index_v._int;
		
			if (index < 0 || index >= object._array.values.len()) {
				self.diagnostic.error(idx.index.span, "index out of bounds");
				return RUNTIME_ERROR~;
			}
			return object._array.values[index];
		}
		case RECORD: {
			if (index_v.kind != STRING) {
				self.diagnostic.error(idx.index.span, "provided value was not a STRING");
				return RUNTIME_ERROR~;
			}
			String index = index_v._string;
			if (!object._record.values.has_key(index)) {
				self.diagnostic.error(idx.index.span, "cannot find field");
				return RUNTIME_ERROR~;
			}

			return object._record.values[index];
		}
		default: {
			self.diagnostic.error(idx.object.span, "value isn't indexable");
			return RUNTIME_ERROR~;
		}
	}
			
	
}
