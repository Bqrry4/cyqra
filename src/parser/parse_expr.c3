module cyqra::parser;
import std::collections::list;
import std::collections::set;
import std::io;

import cyqra::lexer::token;
import cyqra::lexer::span;
import cyqra::diagnostic;
import utils::nullable;

fn Expr*? Parser.expr_head(&self)
{
	Span start = self.cursor.peek(RAW).span;

	Token tk = self.cursor.peek();
	switch(tk.kind) {
		//& literal
		case INTEGER:
		case FLOAT:
			self.cursor.advance();
			return expr::@new(Primary,
				{ .token = tk },
				self.stmt_span(start)
			);
		case D_QUOTES: return self.parse_str();
		//& identifier
		//& shell_call 
		case IDENTIFIER: {
			Expr* ident = self.parse_ident();
			
			if (self.nms.has(ident.primary.token.span.slice) ||
				self.cursor.match(OPEN_PARENTHESIS, RAW)
			) return ident;

			return self.parse_shell_call(ident);
		}	
		//& sub_expression 
		case OPEN_PARENTHESIS: return self.parse_subexpr();
		case OPEN_BRACKET: return self.parse_array();
		case OPEN_BRACE: return self.parse_record();
		default: {
			//& prefix_op , expression
			if(try op = op::check_prefix(tk.kind)) {
				self.cursor.advance();
				
				Expr* rhs = self.parse_expression(op::PREFIX_PREC)!;
				return expr::@new(Prefix,
					{ .op = op, .rhs = rhs },
					self.stmt_span(start)
				);
			}
			io::printn(tk);
			self.fill_diagnostic("unexpected token");
			return ast::INVALID_EXPRESSION~;
		}
	}
}

fn Expr*? Parser.parse_expression(&self, Precedence base_prec = 0)
{
	Span start = self.cursor.peek(RAW).span;

	Expr* expr = self.expr_head()!;
	//& { expr_tail }
	while (true) {

		//! TODO: Check for a possible continuation "\",
		// when present skip it and continue the expression,
		// otherwise lookahead for permitted ops with implicit continuation, like (&&, ||) 
		if (self.cursor.match(NEW_LINE, KEEP_SEP)){
			//
		}
	
		//& "(" , [ argument_list ] , ")"
		if (self.cursor.match(OPEN_PARENTHESIS)) {
			expr = self.parse_call(expr)!;		
			continue;
		}
		//& "[" , expression , "]"
		if (self.cursor.match(OPEN_BRACKET)) {
			expr = self.parse_index(expr)!;
			continue;
		}
		
		Token tk = self.cursor.peek(KEEP_SEP);
		//& postfix_op
		if (try op_def = op::check_postfix(tk.kind, base_prec)) {
			self.cursor.advance();
			
			expr = expr::@new(Postfix,
				{ expr, op_def.op },
				self.stmt_span(start)
			);
			continue;	
		}
		
		//& infix_op , expression
		if (try op_def = op::check_infix(tk.kind, base_prec)) {
			self.cursor.advance();
			
			Expr* rhs = self.parse_expression(op_def.prec)!;
			expr = expr::@new(Infix,
				{ expr, op_def.op, rhs },
				self.stmt_span(start)
			);
			continue;
		}
		break;
	}
	return expr;
}

fn Expr*? Parser.parse_subexpr(&self)
{
	self.cursor.advance_check(OPEN_PARENTHESIS);
	Expr* expr = self.parse_expression()!;
	if(!self.cursor.follows(CLOSED_PARENTHESIS)) {
		self.fill_diagnostic("expected ')'");
		return ast::INVALID_EXPRESSION~;
	}	
	return expr;
}


fn Expr*? Parser.parse_array(&self)
{
	Span start = self.cursor.advance_check(OPEN_BRACKET).span;

	List{ Expr* } elements;
	elements.init(mem);

    while (!self.cursor.match(CLOSED_BRACKET)) {
        elements.push(self.parse_expression()!);

        if (!self.cursor.follows(COMMA)) break;
     }

    if (!self.cursor.follows(CLOSED_BRACKET)) {
        self.fill_diagnostic("expected ']'");
        return ast::INVALID_EXPRESSION~;
    }
	
	return expr::@new(Array,
		{ elements },
		self.stmt_span(start)
	);
}
fn Expr*? Parser.parse_record(&self)
{
	Span start = self.cursor.advance_check(OPEN_BRACE).span;

	List{ Expr* } init_vals;
	init_vals.init(mem);
	
	if(!self.cursor.follows(CLOSED_BRACE)) {

    	if(!self.cursor.follows(CLOSED_BRACE)) {
			self.fill_diagnostic("expected '}'");
			return ast::INVALID_EXPRESSION~;				
		}
	}

	return expr::@new(Record,
		{  },
		self.stmt_span(start)
	);
}
fn StringPart? Parser.parse_interp_ident(&self)
{
	self.cursor.advance_check(INTERP_IDENT);
	
	if (!self.cursor.match(IDENTIFIER)) {
		self.fill_diagnostic("expected identifier");
		return ast::INVALID_EXPRESSION~;
	}
	Expr* ident = self.parse_ident();
	return {
		.kind = INTERP,
		.interp = ident
	};
}

fn StringPart? Parser.parse_interp(&self)
{
	self.cursor.advance_check(INTERP_START);
		
	Expr* content = self.parse_expression()!;

	if (!self.cursor.follows(INTERP_END)) {
		self.fill_diagnostic("expected '}'");
		return ast::INVALID_EXPRESSION~;			
	}
	return {
		.kind = INTERP,
		.interp = content
	};
}

fn StringPart Parser.parse_string_part(&self)
{
	Token tk = self.cursor.advance_check(STRING_PART);
	return {
		.kind = TEXT,
		.text = tk.span.slice 	
	};
}

fn Expr*? Parser.parse_str(&self)
{
	Span start = self.cursor.advance_check(D_QUOTES).span;
	
	List{ StringPart } parts;
	parts.init(mem);

	while (!self.cursor.follows(D_QUOTES)) {
		StringPart part;
		Token tk = self.cursor.peek();
		
		switch (tk.kind) {
			case STRING_PART: part = self.parse_string_part();
			case INTERP_START: part = self.parse_interp()!;	
			case INTERP_IDENT: part = self.parse_interp_ident()!;
			default: unreachable("Unexpected token in string body");
		}
		parts.push(part);
	}
	return expr::@new(StringLit,
		{ parts },
		self.stmt_span(start)
	);
}

fn Expr*? Parser.parse_call(&self, Expr* callee)
{
	self.cursor.advance_check(OPEN_PARENTHESIS);
	List{ Expr* } args;
	args.init(mem);

	while (!self.cursor.match(CLOSED_PARENTHESIS)) {
        args.push(self.parse_expression()!);

        if (!self.cursor.follows(COMMA)) break;
     }

    if (!self.cursor.follows(CLOSED_PARENTHESIS)) {
        self.fill_diagnostic("expected ')'");
        return ast::INVALID_EXPRESSION~;
    }	
 		
	return expr::@new(Call,
		{ callee, args },
		self.stmt_span(callee.span)
	);
}

fn Expr*? Parser.parse_index(&self, Expr* indexed)
{
	Span start = self.cursor.advance_check(OPEN_BRACKET).span;
	
	Expr* index = self.parse_expression()!;
	if(!self.cursor.follows(CLOSED_BRACKET)) {
		self.fill_diagnostic("expected ']'");
		return ast::INVALID_EXPRESSION~;				
	}

	return expr::@new(Index,
		{ indexed, index },
		self.stmt_span(start)
	);
}

fn Expr* Parser.parse_ident(&self)
{
	Token ident = self.cursor.advance_check(IDENTIFIER);
	Span start = ident.span;

	return expr::@new(Primary,
		{ .token = ident },
		ident.span
	);
}


<* [ \n;|})] *>
fn bool is_shell_call_terminator(TokenKind kind)
{
	return is_line_terminator(kind) ||
		kind == SPACE ||
		kind == PIPE ||
		kind == CLOSED_BRACE ||
		kind == CLOSED_PARENTHESIS ||
		kind == EOF;
}

fn Expr*? Parser.parse_shell_call(&self, Expr* callee)
{
	Span start = callee.span;

	List{ Expr* } args; args.init(mem);		
	while (self.cursor.follows(SPACE)) {
	
		Token tk = self.cursor.peek(KEEP_SEP);
		if (is_shell_call_terminator(tk.kind)) break;

		if (self.cursor.match(OPEN_PARENTHESIS)) {
			args.push(self.parse_subexpr()!);
			continue;
		}

		args.push(self.parse_shell_arg()!);
	}

	return expr::@new(Call,
		{ callee, args },
		self.stmt_span(start)
	);
}

fn Expr*? Parser.parse_shell_arg(&self)
{
	Span start = self.cursor.peek(RAW).span;

	List{ StringPart } parts;
	parts.init(mem);

	Token tk;
	//@ consume tokens greedily until terminator 
	do {
		tk = self.cursor.peek();
		//!! TODO: Fix for normal string
		StringPart part;
		switch (tk.kind) {
			case INTERP_START: part = self.parse_interp()!;
			case INTERP_IDENT: part = self.parse_interp_ident()!;
			default: {
				self.cursor.advance();	
				part = {
					.kind = TEXT,
					.text = tk.span.slice 	
				};
			}
		}

		parts.push(part);

		// check if there's more to follow
		tk = self.cursor.peek(RAW);
	} while (!is_shell_call_terminator(tk.kind));

	return expr::@new(StringLit,
		{ parts },
		self.stmt_span(start)
	);
}


