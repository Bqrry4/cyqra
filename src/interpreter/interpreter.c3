module cyqra::interpreter @if(false);
import std::io;
import std::math;
import std::collections::list;
import std::collections::map;
import std::os::process;

import cyqra::lexer::token;
import cyqra::ast;
import cyqra::diagnostic;
import std::net::os;
import std::os::posix;
import libc;

import utils;

faultdef
		RUNTIME_ERROR,
		NOT_A_FUNCTION,
		NOT_ASSIGNMENT,
		INVALID_ARGS_COUNT,
		IDENTIFIER_NOT_FOUND,
		//! Temporary solution for the return from functions using faults
		RETURN_STATEMENT;

struct Interpreter
{
	Scope* scope;
	Diagnostic* diagnostic;

	//! temporary solution
	Value* return_value;
}

fn Interpreter new(
	Diagnostic* diagnostic
){
	Scope* scope = scope::new_ref(mem);
	return {
		.scope = scope,
		.diagnostic = diagnostic
	};
}

fn void Interpreter.free(&self)
{
	self.scope.free();
	alloc::free(mem, self.scope);
}

fn void Interpreter.interpret(&self, Ast ast)
{
	Value* last = mem::@clone(value::UNIT);
	foreach (expr: ast.expressions) {
		if (catch err = @try(last, self.eval(expr))) {
			io::printn(err);
			io::printn(self.diagnostic);
		}
	}
	if (last.kind != UNIT) {
		String s_val = last.to_string(tmem);
		io::printn(s_val);
		s_val.free(tmem);
	}
}

fn Value*? Interpreter.eval(&self, Expr* expr)
{
	switch (expr.kind) {
		case LITERAL: return self.eval_literal(expr);
		case VARIABLE: return self.eval_variable(expr);
		// case STRINGLIT: return self.eval_string(expr);
		// case PREFIX: return self.eval_prefix(expr);
		// case POSTFIX: return self.eval_postfix(expr);
		case INFIX: return self.eval_infix(expr);
		case CALL: return self.eval_call(expr);
		case INDEX: return self.eval_index(expr);
		case BINDING: return self.eval_binding(expr);
		// case BLOCK: return self.eval_block(&expr.block);
		// case FUNCTION: return self.eval_fn(expr);
		case RETURN: return self.eval_return(expr);
		// case ARRAY: return self.eval_array(expr);
		// case RECORD: return self.eval_record(expr);
		case PIPELINE: return self.eval_pipeline(expr);
		default: io::printf("not implemented %s", expr.kind);
	}
	return mem::@clone(value::UNIT);
}

fn Value*? Interpreter.eval_variable(&self, Expr* expr)
{
	Variable* v = &expr.variable;

	Value*? val = self.scope.get(v.id);
	return val;
}

fn Value*? Interpreter.eval_literal(&self, Expr* expr)
{
	Literal* l = &expr.literal;

	switch (l.type) {
		case INT: return mem::@clone(value::_int(l._int));
		case FLOAT: return mem::@clone(value::_float(l._float));
		case STRING: return self.eval_string(l._string);
		default: unreachable("unexpected literal");
	}
}

fn Value*? Interpreter.eval_string(&self, LiteralString lstr)
{
	if (lstr.kind == STATIC) {
		return mem::@clone((Value) {
			.kind = STRING,
			._string = lstr.static_str
		});
	}

	DString dstring = (DString){}.init(mem);
	
	foreach (part: lstr.dyn_str) {
		switch (part.kind) {
			case TEXT:
				dstring.append(part.text);
			case INTERP:
				Value* val = self.eval(part.interp)!;
				dstring.append(val.to_string(mem));			
		}
	}

	String result = dstring.copy_str(mem);
	dstring.free();
	
	return mem::@clone((Value) {
		.kind = STRING,
		._string = result
	});
}

fn Value*? Interpreter.eval_infix(&self, Expr* expr)
{
    Infix* ifx = &expr.infix;

	// TODO: find a cleaner solution
	// if (ifx.op == FIELD) {
 // 		Value lhs = self.eval(ifx.lhs)!.get();
	// 	if (lhs.kind != RECORD) {
	// 		self.diagnostic.error(ifx.lhs.span, "value must be a RECORD");
	// 		return RUNTIME_ERROR~;
	// 	}
	// 	String index = ifx.rhs.span.slice;
	// 	if (!lhs._record.values.has_key(index)) {
	// 		self.diagnostic.error(ifx.rhs.span, "cannot find field");
	// 		return RUNTIME_ERROR~;
	// 	}
	// 	return ref(&lhs._record.values[index]);
	// }

    Value* lhs = self.eval(ifx.lhs)!;
    Value* rhs = self.eval(ifx.rhs)!;

    // if (try val = self.eval_assign(ifx, lhs, rhs)) return val;
	
    return value::apply_op(ifx.op, lhs, rhs);
}

// fn Value*? Interpreter.eval_assign(&self, Infix* ifx, Value* lhs, Value* rhs)
// {
// 	if (lhs.kind != REF) {
// 		self.diagnostic.error(ifx.lhs.span, "the lhs is not assignable");
// 		return RUNTIME_ERROR~;
// 	}
// 	Value rhs_v = rhs.get();
// 	Value lhs_v = lhs.get();
// 	switch (ifx.op) {
//         case ADD_ASGN:
// 			rhs_v = value::apply_op(ADD, lhs_v, rhs_v)!;
// 			nextcase ASGN;
// 		case SUB_ASGN:
// 			rhs_v = value::apply_op(SUB, lhs_v, rhs_v)!;
//         case MUL_ASGN:
// 			rhs_v = value::apply_op(MUL, lhs_v, rhs_v)!;
// 		case DIV_ASGN:
// 			rhs_v = value::apply_op(DIV, lhs_v, rhs_v)!;
//         case ASGN:
// 			*(lhs.ref) = rhs_v;
// 		default: return NOT_ASSIGNMENT~;
// 	}
// 	return val(value::UNIT);
// }
fn Value*? Interpreter.eval_prefix(&self, Expr* expr)
{
    Prefix* pfx = &expr.prefix;
	Value* rhs = self.eval(pfx.rhs)!;
    switch (pfx.op) {
        case POS: return (value::pos(rhs));
        case NEG: return (value::neg(rhs));
        case NOT: return (value::not(rhs));
        default: unreachable("unhandled prefix op");
    }
}
fn Value*? Interpreter.eval_binding(&self, Expr* expr)
{
	Binding* bnd = &expr.bnd;
	Value* value = self.eval(bnd.value)!;

	
	self.scope.set(bnd.typed_name.ident.id, value);
	// switch (bnd.type) {
	// 	case LET:
	// 	case MUT:
	// 		self.scope.set(bnd.id, value);
	// 	//! TODO env
	// 	case ENV:	// os::set_var();
	// 	default: unreachable("Not a binding keyword");			
	// }
	return mem::@clone(value::UNIT);
}

// fn Value*? Interpreter.eval_block(&self, Block* expr, Nullable{ Scope* } scope = nullable::NULL)
// {
// 	// Block* blk = &expr.block;
	
// 	Scope* local_scope = scope.ptr;
// 	// Create an owned scope if not provided
// 	bool owned = scope.is_null();
// 	if (owned) {
// 		local_scope = scope::new_ref(
// 			self.allocator, nullable::value(self.scope)
// 		);	
// 	}
// 	defer if (owned) {
// 		local_scope.free();
// 		alloc::free(self.allocator, local_scope);
// 	}

// 	self.scope = local_scope;
// 	defer {
// 		self.scope = local_scope.parent.ptr;
// 	}
	
// 	Value last = value::UNIT;
// 	foreach (stmt: expr.stmts) {
// 		last = self.eval(stmt)!.get();
// 	}

// 	return val(last);	
// }

// fn Value*? Interpreter.eval_fn(&self, Expr* expr)
// {
// 	Function* fun = &expr.fun;
// 	self.scope.set(fun.identifier.span.slice, {
// 		.kind = FUNCTION,
// 		._fn = {
// 			.params = fun.params,
// 			.body = &fun.body.block
// 		}
// 	});
// 	return val(value::UNIT);
// }
 
enum CallableKind { INTERNAL, EXTERNAL }
union CallablePayload {
	Fn _fn;
    String _cmd;
}

struct Callable {
	inline CallablePayload payload;
    CallableKind kind;	
}

fn Callable? Interpreter.eval_callee(&self, Expr* expr)
{
	Value callee;
	if (expr.kind == EXTERNAL) {
		return { .kind = EXTERNAL, ._cmd = expr.external.name};
	}

	if (callee.is_fn()) {
    	self.diagnostic.error(expr.span, "value is not callable");
    	return RUNTIME_ERROR~;
    }
	return { .kind = INTERNAL, ._fn = callee._fn };
}

fn Value*? Interpreter.eval_call(&self, Expr* expr)
{
	Call* call = &expr.call;
	Callable callable = self.eval_callee(call.callee)!;
	
	List{ Value* } args; args.init(mem, call.args.size);
    defer args.free();

	foreach (arg_expr: call.args) {
		args.push(self.eval(arg_expr)!);
	}
	switch (callable.kind) {
		case INTERNAL: nextcase;
			// return self.call_fn(callable._fn, args.array_view());
		case EXTERNAL:
			Value*? ret = self.call_external(callable._cmd, args.array_view());
			if (catch err2 = ret) {
				self.diagnostic.error(call.callee.span, "command not found");
				return RUNTIME_ERROR~;
			}
		return ret;
	}
}

// fn Value*? Interpreter.call_fn(&self, Fn _fn, Value[] args)
// {	
// 	Scope* fn_scope = scope::new_ref(self.allocator, nullable::value(self.scope));
// 	defer fn_scope.free();

// 	if (_fn.params.len() != args.len) {
// 		return INVALID_ARGS_COUNT~;
// 	}
// 	foreach (i, arg: args) {
// 		fn_scope.set(_fn.params[i], arg);
// 	}
// 	Value returned = value::UNIT;
// 	if (catch err = @try(returned, self.eval_block(_fn.body, nullable::value(fn_scope)).get())) {
// 		if (err == RETURN_STATEMENT) {
// 			return val(self.return_value);
// 		}
// 	}
// 	return val(returned);
// }

<*
	@param [in] cmd
*>
fn Value*? Interpreter.call_external(&self, String cmd, Value*[] cmd_args)
{
	String[] cmd_line = alloc::new_array(mem, String, cmd_args.len + 1);
	defer alloc::free(mem, cmd_line);

	cmd_line[0] = cmd;
	foreach(i, arg: cmd_args) {
		cmd_line[i + 1] = arg.to_string(mem);
	}
	defer foreach (arg: cmd_line[1..]) {
		arg.free(mem);
	}
	
	if (catch err = process::run(cmd_line, INHERIT_STDIO | INHERIT_ENV )) {
		//! It could fail from many reasons,
		// but assume Cmd not found,
		// as stdlib doesnt expose reasons yet
		if (err == process::FAILED_TO_START_PROCESS) {
			return RUNTIME_ERROR~;
		}
	}

	return mem::@clone(value::UNIT);
}

fn Value*? Interpreter.eval_return(&self, Expr* expr)
{
	Return* ret = &expr.ret;
	self.return_value = mem::@clone(value::UNIT);
	if(!ret.value.is_null()) {
		self.return_value = self.eval(ret.value.ptr)!;
	}
	return RETURN_STATEMENT~;
}

fn Value*? Interpreter.eval_array(&self, Expr* expr)
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
fn Value*? Interpreter.eval_record(&self, Expr* expr)
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

fn Value*? Interpreter.eval_index(&self, Expr* expr)
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


enum StageKind {
	EXPRESSION,
	EXTERNAL,
	INTERNAL
}

struct PipeStage {
    StageKind kind;
    union {
        Value expr;
    	struct {
			CallablePayload call;
			List{ Expr* } args;
		}
    }
}

fn PipeStage? Interpreter.eval_and_classify_stage(&self, Expr* expr)
{
    if (expr.kind == CALL) {
		Callable callable = self.eval_callee(expr.call.callee)!;
		return {
			.kind = callable.kind == INTERNAL ? INTERNAL : EXTERNAL,
			.call = callable,
			.args = expr.call.args
		};
    }
    return {
		.kind = EXPRESSION,
		.expr = self.eval(expr)!.get()
	};
}


/*
	special cases
	read path | cmd
	cmd | write path
	cmd | append path
*/

fn Value*? Interpreter.eval_pipeline(&self, Expr* expr)
{
	Pipeline* ppln = &expr.pipeline;

	List{ Process } processes;
    processes.init(self.allocator);
    defer processes.free();

	const INVALID_FD = -1;
	RawFd in_fd = INVALID_FD;

	PipeStage left_stage = self.eval_and_classify_stage(ppln.head)!;
	foreach (link: ppln.links) {
		PipeStage right_stage = self.eval_and_classify_stage(link.expr)!;

		switch (left_stage.kind) {
			case EXTERNAL: switch (right_stage.kind) {
				case EXTERNAL: { 
					String[] cmd_line = self.build_cmd_line(left_stage)!;
					defer self.free_cmd_line(cmd_line);
				
					CInt[2] pipe;
					assert(!posix::pipe(&pipe));

					const int F_SETFD = 2;
					const int FD_CLOEXEC = 1;
					os::fcntl((NativeSocket)pipe[0], F_SETFD, FD_CLOEXEC);
					os::fcntl((NativeSocket)pipe[1], F_SETFD, FD_CLOEXEC);
				
					Process lp = process::spawn(
						cmd_line, INHERIT_ENV,
						in: (in_fd == INVALID_FD) ? process::INHERIT : process::bind(in_fd),
						out: process::bind(pipe[1])
					)!;
					processes.push(lp);
	
					libc::close(pipe[1]);
					if (in_fd != INVALID_FD) {
						libc::close(in_fd);
					}
					in_fd = pipe[0];			
				}
				default:
			}
			default:
		}

		left_stage = right_stage;
	}

	//execute last stage

	switch (left_stage.kind) {
		case EXTERNAL: {	 
			String[] cmd_line = self.build_cmd_line(left_stage)!;
			defer self.free_cmd_line(cmd_line);
				
			Process lp = process::spawn(
				cmd_line, INHERIT_ENV,
				in: (in_fd == INVALID_FD) ? process::INHERIT : process::bind(in_fd),
				out: process::INHERIT
			)!;
			processes.push(lp);
		}
		default:
	}

	
	foreach (p: processes) p.join()!;
	/*
	cmd to cmd -> bind the stdout/in, "returns" the last cmd
	cmd to fun -> pass a Stream object, returns the fun value
	cmd to expr -> pipe ignored, evals and returns expr
	fun or expr to cmd -> string passed to stdin

	when $in is used, it is captured in it
	 */
	return val(value::UNIT);
}


fn String[]? Interpreter.build_cmd_line(&self, PipeStage stage)
{
	List{ Value } args; args.init(self.allocator, stage.args.size);
	defer args.free();

	foreach (arg_expr: stage.args) {
		args.push(self.eval(arg_expr)!.get());
	}
	
	String[] cmd_line = alloc::new_array(self.allocator, String, args.len() + 1);
	defer alloc::free(self.allocator, cmd_line);
			
	cmd_line[0] = stage.call._cmd;
	foreach(i, arg: args) {
		cmd_line[i + 1] = arg.to_string(self.allocator);
	}
	defer foreach (arg: cmd_line[1..]) {
		arg.free(self.allocator);
	}

	return cmd_line;
}
fn void Interpreter.free_cmd_line(&self, String[] cmd_line)
{
    foreach (s: cmd_line[1..]) s.free(self.allocator);
    alloc::free(self.allocator, cmd_line);
}
