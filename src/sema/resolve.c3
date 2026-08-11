module cyqra::sema;
import cyqra::ast;
import cyqra::sema::types;
import cyqra::sema::symbol_pool;
import cyqra::sema::namespace;
import cyqra::diagnostic;
import std::collections::list;
import utils::nullable;

import std::io;
struct InFrame
{
    SymbolID id;
    bool  found;
}

struct Sema {
	Allocator alloc;
	
	SymbolPool symbols;
	Namespace nms;

	Diagnostic* diagnostic;

	// For resolving in keyword
	List{ InFrame } in_stack;
}

fn Sema new(Diagnostic* diagnostic)
{
	SymbolPool symbols = symbol_pool::new(mem);
	Namespace nms = namespace::new(mem);
	nms.enter();

	List{ InFrame } in_stack;
	in_stack.init(mem);

	return {
		.symbols = symbols,
		.nms = nms,
		.diagnostic = diagnostic,
		.in_stack = in_stack,
	};
}

fn void Sema.free(&self) {
	self.nms.leave();
	self.nms.free();
	self.symbols.free();
}

<*
	@param [inout] ast
*>
fn void Sema.resolve(&self, Ast* ast)
{
	//! Reuse the logic for the nested scopes
    foreach (expr: ast.expressions) {
		switch (expr.kind) {
		// check the types
		case BINDING:
			Binding* bnd = &expr.bnd;
			Type type = self.check_binding(bnd);
			bnd.ident.id = self.define_variable(type, bnd.ident.name);
		case FUNCTION: self.check_fn(expr);
		// resolve ambiguities
		case FLAT_SEQUENCE:
			Expr* resolved = self.fold_fseq(&expr.fseq, &&0);
			expr.fseq.free();
			expr.kind = resolved.kind;
			expr.defs = resolved.defs;
			expr::free(resolved);
			nextcase default;
		case AMBIGUOUS_IDENT:
			self.mut_resolve_ambiguous_ident(expr)!!;
			if (expr.kind == FLAT_SEQUENCE) {
				nextcase FLAT_SEQUENCE;
			}
			if (expr.kind == CALL) {
				nextcase CALL;
			}
			nextcase default;
		case CALL:
			//@ Output of a standalone call on external is inherited
			self.infer_call(expr);
			Expr* callee = expr.call.callee;
			if (callee.kind == EXTERNAL) {
				callee.external.mode = INHERITED;
			}
		// infer (checks mismatched type in ops)
		default: (void)self.infer(expr);
		}
    }
}

<* Register prototypes for forward declaration *>
fn void Sema.register_signatures(&self, FnDecl fn_decl)
{
	foreach (fun: fn_decl) {
		List{ Type } formals_t; formals_t.init(self.alloc);
		foreach (param: fun.params) {
			Type t = self.resolve_type(param.type);
			formals_t.push(t);
		}

		SymbolID id = self.symbols.bind(Type.FN, fun.ident.name, {
			formals_t,
			Type.ANY
		});
		fun.ident.id = id;
		self.nms.add(self.symbols.name_of(id), id);
	}
}

fn SymbolID Sema.define_variable(&self, Type type, String name)
{
	SymbolID id = self.symbols.bind(type, name);
	// Borrow the value from the pool with it's id
	self.nms.add(self.symbols.name_of(id), id);
	return id;
}

fn Type Sema.infer(&self, Expr* expr)
{
	switch (expr.kind) {
	case LITERAL: return expr.defs.literal.type;
	case PREFIX: return self.infer_prefix(expr);
	case POSTFIX: return self.infer_postfix(expr);
	case INFIX: return self.infer_infix(expr);
	case IDENTIFIER: return self.infer_ident(expr);
	case CALL: return self.infer_call(expr);
	case PIPELINE: return self.infer_pipeline(expr);
	// case BLOCK: return self.infer_block(expr);
	default:
	}
	return UNIT;
}

fn Type Sema.infer_ident(&self, Expr* expr)
{
	self.classify_ident(expr);
	switch (expr.kind) {
	case VARIABLE:
		return self.symbols.def_of(expr.variable.id).type;
	case EXTERNAL:
		return FN;
	default: unreachable("must be a VARIABLE or EXTERNAL");
	}
}

fn Type Sema.infer_call(&self, Expr* expr)
{
	//! check args and arity as well
	// it must be piggybacked in the type
	return self.infer(expr.call.callee);
}

fn Type Sema.infer_pipeline(&self, Expr* expr)
{
	Pipeline* ppln = &expr.ppln;

	Expr* left;
	foreach (link: ppln.links) {
		left = link.expr;
		Type type = self.infer(link.expr);

		InFrame frame = self.in_stack.pop()!!;
		if (frame.found) {
			link.expr.kind = BINDING;
			link.expr.bnd.typed_name.ident.id = frame.id;
			link.expr.bnd.value = left;
    	}
	}

	Type type = self.infer(ppln.tail);

	return type;
}

fn Type Sema.infer_prefix(&self, Expr* expr)
{
	return self.infer(expr.defs.prefix.rhs);
}
fn Type Sema.infer_postfix(&self, Expr* expr)
{
	return self.infer(expr.defs.postfix.lhs);
}
fn Type Sema.infer_infix(&self, Expr* expr)
{
	Infix* ifx = &expr.defs.infix;
	Type lhs = self.infer(ifx.lhs);
	Type rhs = self.infer(ifx.rhs);
	switch (ifx.op)	{
	case ADD: case SUB:
	case MUL: case MOD:
	case DIV: case FLOOR_DIV:
	case POW: {
		switch {
			case lhs == Type.ANY || rhs == Type.ANY: return Type.ANY;
			case lhs == Type.INT && rhs == Type.INT: return Type.INT;
			case (lhs == Type.FLOAT && rhs == Type.INT)
			|| (lhs == Type.INT && rhs == Type.FLOAT): return Type.FLOAT;
			// Strings can be coerced at runtime to numbers
			case lhs == Type.STRING || rhs == Type.STRING: return Type.ANY;
		}
		io::printn("Incompatible types");
		return {};
	}
	case EQ: case NEQ: return Type.BOOL;
	case LT: case LTE:
	case GT: case GTE: {
		switch {
			case lhs == Type.ANY || rhs == Type.ANY:
 	     		case lhs == Type.STRING || rhs == Type.STRING:
			case (lhs == Type.INT || lhs == Type.FLOAT)
             	  && (rhs == Type.INT || rhs == Type.FLOAT):
				return Type.BOOL;
		}
		io::printn("Incompatible types");
		return {};
	}
	//! TODO
	// case AND: case OR:
	default:
	}
	return UNIT;
}


fn void Sema.check(&self, Expr* expr, Type expected)
{
	if (expected == Type.ANY) {
		(void)self.infer(expr);
		return;
	}

	Type inferred = self.infer(expr);
	if (!types::compatibility(inferred, expected)) {
		io::printn("Incompatible types");
	}
}

fn Type Sema.check_binding(&self, Binding* bnd)
{
	Type type;
	if (bnd.type.is_null()) {
		type = self.infer(bnd.value);
	}
	else {
		type = self.resolve_type(bnd.type);
		self.check(bnd.value, type);
	}
	return type;
}

fn Type Sema.resolve_type(&self, Nullable{ Expr* } type) {
	if (type.is_null()) return Type.ANY;
	return types::resolve(type.ptr.defs.ident.name)!!;
}

fn void Sema.check_fn(&self, Expr* expr)
{
	self.nms.enter();
	defer self.nms.leave();
}

