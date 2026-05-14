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
		NOT_A_FUNCTION,
		NOT_ASSIGNMENT,
		INVALID_ARGS_COUNT,
		IDENTIFIER_NOT_FOUND,
		//! Temporary solution for the return from functions using faults
		RETURN_STATEMENT;

enum ValKind {
	VAL,
	REF
}

struct EValue {
	ValKind kind;
	union {
		Value v;
		Value* ref;
	}
}

macro EValue val(Value value) => {
	.kind = VAL,
	.v = value
};

macro EValue ref(Value* ref) => {
	.kind = REF,
	.ref = ref
};

fn Value EValue.get(&self) {
	if (self.kind == REF) {
		return *self.ref;
	}
	return self.v;
} 

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
	EValue last = val(value::UNIT);
	foreach (expr: ast.expressions) {
		if (catch err = @try(last, self.eval(expr))) {
			io::printn(self.diagnostic);
		}
	}
	if (last.get().kind != UNIT) {
		String s_val = last.get().to_string(self.allocator);
		io::printn(s_val);
		s_val.free(self.allocator);
	}
}

fn EValue? Interpreter.eval(&self, Expr* expr)
{
	switch (expr.kind) {
		case PRIMARY: return self.eval_primary(expr);
		case STRINGLIT: return self.eval_string(expr);
		// case PREFIX: return self.eval_prefix(expr);
		// case POSTFIX: return self.eval_postfix(expr);
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
	return val(value::UNIT);
}

fn EValue? Interpreter.eval_primary(&self, Expr* expr)
{
	Primary* p = &expr.primary;

	String slice = p.token.span.slice;
	TokenKind kind = p.token.kind;
	switch (kind) {
		case INTEGER: return val(value::_int(slice.to_long()!!));
		case FLOAT: return val(value::_float(slice.to_double()!!));
		case IDENTIFIER: {
			Value*? val = self.scope.get_ref(slice);
			if (catch val) {
				self.identifier = slice;
				return IDENTIFIER_NOT_FOUND~;
			}
			return ref(val);
		}
		
		default: unreachable("eval_primary: unexpected token kind '%s'", kind);
	}
}

fn EValue? Interpreter.eval_string(&self, Expr* expr)
{
	StringLit* s = &expr.string;
	DString dstring = (DString){}.init(self.allocator);

	foreach (part: s.parts) {
		switch (part.kind) {
			case TEXT:
				dstring.append(part.text);
			case INTERP:
				Value val = self.eval(part.interp)!.get();
				dstring.append(val.to_string(self.allocator));			
		}
	}

	String result = dstring.copy_str(self.allocator);
	dstring.free();
	
	return val({
		.kind = STRING,
		._string = result
	});
}

fn EValue? Interpreter.eval_infix(&self, Expr* expr)
{
    Infix* ifx = &expr.infix;

    EValue lhs = self.eval(ifx.lhs)!;
    EValue rhs = self.eval(ifx.rhs)!;

    if(try val = self.eval_assign(ifx, lhs, rhs)) return val;

    return val(value::apply_op(ifx.op, lhs.get(), rhs.get()));
}

fn EValue? Interpreter.eval_assign(&self, Infix* ifx, EValue lhs, EValue rhs)
{
	if (lhs.kind != REF) {
		self.diagnostic.error(ifx.lhs.span, "the lhs is not assignable");
		return RUNTIME_ERROR~;
	}
	Value rhs_v = rhs.get();
	Value lhs_v = lhs.get();
	switch (ifx.op) {
        case ADD_ASGN:
			rhs_v = value::apply_op(ADD, lhs_v, rhs_v)!;
			nextcase ASGN;
		case SUB_ASGN:
			rhs_v = value::apply_op(SUB, lhs_v, rhs_v)!;
        case MUL_ASGN:
			rhs_v = value::apply_op(MUL, lhs_v, rhs_v)!;
		case DIV_ASGN:
			rhs_v = value::apply_op(DIV, lhs_v, rhs_v)!;
        case ASGN:
			*(lhs.ref) = rhs_v;
		default: return NOT_ASSIGNMENT~;
	}
	return val(value::UNIT);
}
fn EValue? Interpreter.eval_prefix(&self, Expr* expr)
{
    Prefix* pfx = &expr.prefix;
	Value rhs = self.eval(pfx.rhs)!.get();
    switch (pfx.op) {
        case POS: return val(value::pos(rhs));
        case NEG: return val(value::neg(rhs));
        case NOT: return val(value::not(rhs));
        default: unreachable("unhandled prefix op");
    }
}
fn EValue? Interpreter.eval_binding(&self, Expr* expr)
{
	Binding* bnd = &expr.binding;
	Value value = self.eval(bnd.value)!.get();

	switch (bnd.type) {
		case LET:
		case MUT:
			self.scope.set(bnd.identifier.span.slice, value);
		//! TODO env
		case ENV:	// os::set_var();
		default: unreachable("Not a binding keyword");			
	}
	return val(value::UNIT);
}

fn EValue? Interpreter.eval_block(&self, Block* expr, Nullable{ Scope* } scope = nullable::NULL)
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
		last = self.eval(stmt)!.get();
	}

	return val(last);	
}

fn EValue? Interpreter.eval_fn(&self, Expr* expr)
{
	Function* fun = &expr.fun;
	self.scope.set(fun.identifier.span.slice, {
		.kind = FUNCTION,
		._fn = {
			.params = fun.params,
			.body = &fun.body.block
		}
	});
	return val(value::UNIT);
} 


fn EValue? Interpreter.eval_call(&self, Expr* expr)
{
	Call* call = &expr.call;
	Value callee; 
    fault err = @catch(
		@try(callee, self.eval(call.callee).get())
	);

    if (err && err != IDENTIFIER_NOT_FOUND) return err~;

	List{ Value } args; args.init(self.allocator, call.args.size + 1);
    defer args.free();

	//@ Add dummy value for the external call
	args.push(value::UNIT);
	foreach (arg_expr: call.args) {
		args.push(self.eval(arg_expr)!.get());
	}

    if (err == IDENTIFIER_NOT_FOUND) {
		args[0] = value::_string(self.identifier);
		Value? ret = self.call_external(args.array_view()).get();
		if (catch err2 = ret) {
			self.diagnostic.error(call.callee.span, "command not found");
			return RUNTIME_ERROR~;
		}
		return val(ret);
	}
	
	if (!callee.is_fn()) return NOT_A_FUNCTION~;
	return self.call_fn(callee._fn, args.array_view()[1..]);
}


fn EValue? Interpreter.call_fn(&self, Fn _fn, Value[] args)
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
	if (catch err = @try(returned, self.eval_block(_fn.body, nullable::value(fn_scope)).get())) {
		if (err == RETURN_STATEMENT) {
			return val(self.return_value);
		}
	}
	return val(returned);
}

fn EValue? Interpreter.call_external(&self, Value[] cmd_args)
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

	return val(value::UNIT);
}

fn EValue? Interpreter.eval_return(&self, Expr* expr)
{
	Return* ret = &expr.ret;
	self.return_value = value::UNIT;
	if(!ret.value.is_null()) {
		self.return_value = self.eval(ret.value.ptr)!.get();
	}
	return RETURN_STATEMENT~;
}

fn EValue? Interpreter.eval_array(&self, Expr* expr)
{
	Array* arr = &expr.array;

	List{ Value } values; values.init(self.allocator);
	foreach (expr_val : arr.elements) {
		values.push(self.eval(expr_val)!.get());
	}
	return val({
		.kind = ARRAY,
		._array = { values }
	});
}
fn EValue? Interpreter.eval_record(&self, Expr* expr)
{
	Record* rec = &expr.record;
	HashMap{ String, Value } values; values.init(self.allocator);

	foreach (field : rec.fields) {
		//TODO: remake identifiers to a separate, non-primary struct
		String key;
		if (field.key.primary.token.kind == IDENTIFIER) {
			key = field.key.primary.token.span.slice.copy(self.allocator);
		} else {
			key = self.eval(field.key).get().to_string(self.allocator)!;
		}
		Value value = self.eval(field.value)!.get();
		values.set(key, value);
	}
	return val({
		.kind = RECORD,
		._record = { values }
	});
}

fn EValue? Interpreter.eval_index(&self, Expr* expr)
{
	Index* idx = &expr.index;
	Value index_v = self.eval(idx.index)!.get();
	Value object = self.eval(idx.object)!.get();
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
			return ref(&object._array.values[index]);
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

			return ref(&object._record.values[index]);
		}
		default: {
			self.diagnostic.error(idx.object.span, "value isn't indexable");
			return RUNTIME_ERROR~;
		}
	}
			
	
}
