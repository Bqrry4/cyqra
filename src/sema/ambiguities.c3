module cyqra::sema;
import cyqra::ast;
import cyqra::parser;
import cyqra::lexer::token;


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
		self.mut_resolve_ambiguous_ident(lhs)!!;
		if (lhs.kind == FLAT_SEQUENCE) {
			lhs = self.fold_fseq(&lhs.fseq, &&0, prec);
		}
		//should check if its an fseq, it must be continued from it with the current info
		// is it just passing the current prec to a new fold_fseq call?
	case FLAT_SEQUENCE: //nested
		Expr* resolved = self.fold_fseq(&lhs.fseq, &&0);
		lhs.fseq.free();
		lhs.kind = resolved.kind;
		lhs.defs = resolved.defs;
		expr::free(resolved);
	case IN:
		self.handle_in_keyword(lhs)!!;
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
fn void? Sema.mut_resolve_ambiguous_ident(&self, Expr* expr)
{
	Expr* ident = mem::@clone(*expr);
	self.classify_ident(ident);

	bool is_shell_call = self.is_shell_callable(ident);
	Token[] trailing = expr.amb_ident.trailing;

	if (trailing.len == 0) {
		mut_resolve_bare(expr, ident, is_shell_call);
		return;
	}
		
	Parser parser;
	parser.diagnostic = self.diagnostic;
	parser.cursor.tokens = trailing;
	mut_resolve_trailing(&parser, expr, ident, is_shell_call)!;
}

<*
	Classify an ident by scope lookup, mutating it in place
	to VARIABLE or EXTERNAL.

	@param [inout] ident
*>
fn void Sema.classify_ident(&self, Expr* ident)
{
	String name = ident.ident.name;
	if (try id = self.nms.get(name)) {
		*ident = {
			.kind = VARIABLE,
			.defs = { .variable = { id } },
			.span = ident.span
		};
		return;
	}
	*ident = {
		.kind = EXTERNAL,
		.defs = { .external = { .name = name } },
		.span = ident.span
	};
}

<*
	@param [in] ident
*>
fn bool Sema.is_shell_callable(&self, Expr* ident)
{
	switch (ident.kind) {
	case VARIABLE:
		SymbolID id = ident.variable.id;
		Type type = self.symbols.def_of(id).type;
		return (type == FN);
	case EXTERNAL:
		return true;
	default: unreachable("not an external or variable");
	}
}
<*
	@param [out] out
	@param [in] ident
*>
fn void mut_resolve_bare(Expr* out, Expr* ident, bool is_shell_call) @local
{
	if (is_shell_call) {
		// promote it to a call
		out.kind = CALL;
		out.call = { .callee = ident };
		return;
	}
	out.kind = ident.kind;
	out.defs = ident.defs;
}
<*
	@param [in] parser
	@param [out] out
	@param [in] ident
*>
fn void? mut_resolve_trailing(Parser* parser, Expr* out, Expr* ident, bool is_shell_call) @local
{
	Expr* resolved @noinit;
	if (is_shell_call) {
		resolved = parser.parse_shell_call(ident)!;
	}
	else {
		FlatSequence fseq; fseq.init(mem);
		fseq.push(ident);
		resolved = parser.parse_expression_tail(&fseq)!;
	}
	
	out.kind = resolved.kind;
	out.defs = resolved.defs;
	expr::free(resolved);
}

fn void? Sema.handle_in_keyword(&self, Expr* expr)
{
	if (!self.in_stack.len()) {
		// self.fill_diagnostic("`in` outside pipeline");
		return ast::INVALID_EXPRESSION~;
	}

	InFrame* frame = &self.in_stack[^1];
	if (frame.id == symbol_pool::INVALID_SYMBOL) {
		frame.id = self.symbols.bind(UNIT, "in");
	}
	frame.found = true;

	expr.kind = VARIABLE;
	expr.variable.id = frame.id;
}
