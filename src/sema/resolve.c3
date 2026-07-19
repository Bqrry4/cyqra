module cyqra::sema;
import cyqra::ast;
import cyqra::sema::types;
import cyqra::sema::symbol_pool;
import cyqra::sema::namespace;
import cyqra::parser;
import std::collections::list;
import utils::nullable;
import std::io;

struct Sema {
	Allocator alloc;
	
	SymbolPool symbols;
	Namespace nms;

	Parser* parser;
}

fn Sema new(Allocator alloc)
{
	SymbolPool symbols = symbol_pool::new(alloc);
	Namespace nms = namespace::new(alloc);
	nms.enter();

	return {
		.alloc = alloc,
		.symbols = symbols,
		.nms = nms,
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
    foreach (expr: ast.expressions) {
		switch (expr.kind) {
		// check the types
		case BINDING: self.check_binding(expr);
		case FUNCTION: self.check_fn(expr);
		// resolve ambiguities
		case FLAT_SEQUENCE:
			Expr* resolved = self.fold_fseq(&expr.fseq, &&0);
			expr.fseq.free();
			expr.kind = resolved.kind;
			expr.defs = resolved.defs;
			expr::free(resolved);
		case AMBIGUOUS_IDENT:
			// mutate the node
			self.resolve_ambiguous_ident(expr)!!;
			nextcase default;
		// infer (checks mismatched type in ops)
		default: (void)self.infer(expr);
		}
    }
}

<* Register prototypes for forward declaration *>
fn void Sema.register_signatures(&self, List{ Function* } fn_decl)
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
	// case CALL: return self.infer_call(expr);
	// case BLOCK: return self.infer_block(expr);
	default:
	}
	return UNIT;
}

<*
	Fold a flat sequence by mutating the operators to the coresponding expression type.
	@param [in] fseq
	@param [inout] pos
*>
fn Expr* Sema.fold_fseq(&self, FlatSequence* fseq, sz* pos, Precedence prec = 0)
{
	Expr* lhs = fseq.[*pos];
	(*pos)++;

	switch(lhs.kind) {
	case OPERATOR:
		Operator op = lhs.defs.op;
		// sanity check
		assert(op.fx == PREFIX);
		Expr* rhs = self.fold_fseq(fseq, pos, op.prec);

		lhs.kind = PREFIX;
		lhs.defs.prefix = { op, rhs };
	case AMBIGUOUS_IDENT:
		self.resolve_ambiguous_ident(lhs)!!;
		//should check if its an fseq, it must be continued from it with the current info
		// is it just passing the current prec to a new fold_fseq call?
	case FLAT_SEQUENCE: //nested
		Expr* resolved = self.fold_fseq(&lhs.fseq, &&0);
		lhs.fseq.free();
		lhs.kind = resolved.kind;
		lhs.defs = resolved.defs;
		expr::free(resolved);
	default: //nothing
	}

	while (*pos < fseq.len()) {
		Expr* peek = fseq.[*pos];
		Operator op = peek.defs.op;
		//! Need testing
		if (op.prec < prec) break;			
		(*pos)++;
		
		switch (op.fx) {
		case POSTFIX:
			peek.kind = POSTFIX;
			peek.defs.postfix = { lhs, op };
		case INFIX:
			Expr* rhs = self.fold_fseq(fseq, pos,
				(op.as == LEFT) ? op.prec + 1 : op.prec
			);
			peek.kind = INFIX;
			peek.defs.infix = { lhs, op, rhs };
		default: unreachable("operator must be either postfix or infix");
		}
		lhs = peek;
	}
	return lhs;
}

<*
	@param [inout] expr
*>
fn void? Sema.resolve_ambiguous_ident(&self, Expr* expr)
{
	Expr* ident;
	bool is_shell_call;
	String name = expr.amb_ident.name;

	if (try id = self.nms.get(name)) {
		ident = expr::@new(VARIABLE,
			{ id },
			expr.span
		);

		Type type = self.symbols.def_of(id).type;
		is_shell_call = (type == FN);
	}
	else {
		ident = expr::@new(EXTERNAL,
			{ name },
			expr.span
		);
		//@ An external is always a shell call
		is_shell_call = true;
	}

	Expr* resolved @noinit;
	if (is_shell_call) {
		resolved = self.parser.parse_shell_call(ident)!;
	}
	else {
		FlatSequence fseq; fseq.init(self.alloc);
		resolved = self.parser.parse_expression_tail(&fseq)!;
	}
	expr.kind = resolved.kind;
	expr.defs = resolved.defs;
	expr::free(resolved);
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

fn void Sema.check_binding(&self, Expr* expr)
{
	Binding* bnd = &expr.defs.bnd;

	Type type;
	if (bnd.type.is_null()) {
		type = self.infer(bnd.value);
	}
	else {
		type = self.resolve_type(bnd.type);
		self.check(bnd.value, type);
	}

	bnd.ident.id = self.define_variable(type, bnd.ident.name);
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

