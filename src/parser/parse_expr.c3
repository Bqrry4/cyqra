module cyqra::parser;
import std::collections::list;
import std::collections::set;
import std::io;

import cyqra::ast;
import utils::nullable;
import cyqra::lexer::token;
import cyqra::lexer::span;
import cyqra::diagnostic;
import cyqra::sema::types;

fn Expr* Parser.parse_int(&self) @inline
{
	Span span = self.cursor.advance_check(INTEGER).span;
	return expr::@new(LITERAL,
		{
			.type = Type.INT,
			._int = span.slice.to_long()!!
		},
		self.stmt_span(span),
	);
}
fn Expr* Parser.parse_float(&self) @inline
{
	Span span = self.cursor.advance_check(FLOAT).span;
	return expr::@new(LITERAL,
		{
			.type = Type.FLOAT,
			._float = span.slice.to_double()!!
		},
		self.stmt_span(span),
	);
}

<*
	@param [inout] fseq
*>
fn void? Parser.expr_head(&self, FlatSequence* fseq)
{
	while (true) {
		Token tk = self.cursor.peek();
		Operator op = op::to_prefix(tk.kind);
		if (op != INVALID) {
			self.cursor.advance();
			fseq.push(expr::@new(OPERATOR,
				op,
				tk.span
			));
		} else { break; }
	} 

	Expr* expr;
	switch(self.cursor.peek().kind) {
	//& literal
	case INTEGER: expr = self.parse_int();
	case FLOAT: expr = self.parse_float();
	case D_QUOTES: expr = self.parse_str()!;
	//& identifier
	//& shell_call 
	case IDENTIFIER:
		expr = self.parse_ident()!;

		/* An ident followed by space could be a shell call */
		if (self.cursor.follows(SPACE)) {
			self.mut_ambiguous_ident(expr);
			break;
		}

	//& sub_expression 
	case OPEN_PARENTHESIS: expr = self.parse_subexpr()!;
	case OPEN_BRACKET: expr = self.parse_list()!;
	case OPEN_BRACE: expr = self.parse_record()!;
	case AMP: expr = self.parse_lambda()!;
	case IN: expr = self.parse_in();
	default:
		self.fill_diagnostic("unexpected token");
		return ast::INVALID_EXPRESSION~;
	}

	// tight suffixes
	while (true) {
		switch {
		case self.cursor.match(OPEN_PARENTHESIS, KEEP_SEP):
			expr = self.parse_call(expr)!;
			continue;
		case self.cursor.match(OPEN_BRACKET, KEEP_SEP):
			expr = self.parse_index(expr)!;
			continue;
		case self.cursor.match(DOT, KEEP_SEP):
			expr = self.parse_dot_access(expr)!;
			continue;
		case self.cursor.match(OPEN_BRACE, KEEP_SEP):
			// expr = self.parse_trailing_lambda(expr)!;
			continue;
		}
		break;
	}
	fseq.push(expr);
}

fn PipeMode pipe_mode_from(Operator tk)
{
	switch (tk) {
		case PIPE:     return OUT;
		case PIPE_ERR: return ERR;
		case PIPE_ALL: return OUT_ERR;
		default: unreachable("Provided operator is not a PIPE");
	}
}
fn Expr* Parser.finish_fseq(&self, FlatSequence* fseq, Span span)
{
	if (fseq.len() == 1) {
		Expr* leaf = fseq.[0];
		fseq.free();
		return leaf;
	}
	return expr::@new(FLAT_SEQUENCE, *fseq, span);
}

fn Expr*? Parser.parse_expression(&self)
{
	Span outer_start = self.cursor.peek(RAW).span;

	Span stage_start = outer_start;
	// Span start = self.cursor.peek(RAW).span;
	FlatSequence fseq; fseq.init(self.alloc);
	// Pipeline handling
	List{ PipelineLink } links; links.init(mem);

	self.expr_head(&fseq)!;
	while (true) {

		//! TODO: line-continuation
		// lookahead (&&, ||, |, ...)
		// the line continuator '\' should be handled in the lexer

		Token tk = self.cursor.peek(KEEP_SEP);
		Operator pfx = op::to_postfix(tk.kind);
		if (pfx != INVALID) {
			self.cursor.advance();
			fseq.push(expr::@new(OPERATOR, pfx, tk.span));
			continue;
		}

		//& infix_op , expression
		Operator ifx = op::to_infix(tk.kind);
		if (ifx != INVALID) {
			self.cursor.advance();
			switch (ifx) {
			case PIPE: case PIPE_ERR: case PIPE_ALL:
				Expr* stage = self.finish_fseq(&fseq, stage_start);
				links.push({ stage, pipe_mode_from(ifx) });

				fseq = (FlatSequence){};
				fseq.init(self.alloc);
				stage_start = self.cursor.peek(RAW).span;
				self.expr_head(&fseq)!;
				continue;
			default:
				fseq.push(expr::@new(OPERATOR, ifx, tk.span));
				// rhs
				self.expr_head(&fseq)!;
				continue;
			}
		}
		break;
	}

	Expr* tail = self.finish_fseq(&fseq, stage_start);
	if (links.len() == 0) return tail;   // no pipe ever seen

	return expr::@new(PIPELINE, { links, tail }, outer_start.extend(tail.span));
}

<*
	Mutates an ident to an ambiguous ident, that slurps anything
	that could potentially lead to a valid shell call.
*>
fn void Parser.mut_ambiguous_ident(&self, Expr* ident)
{
	ident.kind = AMBIGUOUS_IDENT;

	sz start = self.cursor.current;

	/* Consume the whole expression that could be a call,
		after the ident */
	int depth = 0;
	while (true) {
		Token tk = self.cursor.peek(KEEP_SEP);

		/* We must count for nesting before expecting a valid terminator */
		if (tk.kind == OPEN_PARENTHESIS) depth++;
		if (tk.kind == CLOSED_PARENTHESIS) depth--;
		if (tk.kind == INTERP_START) depth++;
		if (tk.kind == INTERP_END) depth--;
		if (!depth && is_shell_call_terminator(tk.kind)) break;

		self.cursor.advance();
	}

	sz end = self.cursor.current;
	Token[] trailing = self.cursor.tokens[start..end - 1];

	ident.amb_ident.trailing = trailing;
}

fn Expr*? Parser.parse_ident(&self)
{
	Token ident = self.cursor.advance_check(IDENTIFIER);
	return expr::@new(IDENTIFIER,
		{ ident.span.slice },
		ident.span
	);
}

fn Expr*? Parser.parse_ident_as_string(&self)
{
	Token ident = self.cursor.advance_check(IDENTIFIER);
	return expr::@new(LITERAL,
		{
			.type = STRING,
			._string = { STATIC, ident.span.slice }
		},
		ident.span
	);}

fn Expr* Parser.parse_in(&self)
{
	Span start = self.cursor.advance_check(IN).span;

	return mem::new(Expr, {
		.kind = IN,
		.span = start
	});
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

fn Expr*? Parser.parse_list(&self)
{
	Span start = self.cursor.advance_check(OPEN_BRACKET).span;

	List{ Expr* } elements; elements.init(mem);
    while (!self.cursor.match(CLOSED_BRACKET)) {
        elements.push(self.parse_expression()!);

        if (!self.cursor.follows(COMMA)) break;
     }

    if (!self.cursor.follows(CLOSED_BRACKET)) {
        self.fill_diagnostic("expected ']'");
        return ast::INVALID_EXPRESSION~;
    }
	
	return expr::@new(LITERAL,
		{
			.type = Type.LIST,
			._list = elements
		},
		self.stmt_span(start),
	);
}
fn Expr*? Parser.parse_record(&self)
{
	Span start = self.cursor.advance_check(OPEN_BRACE).span;

	List{ RecordField } fields; fields.init(mem);
	while (!self.cursor.match(CLOSED_BRACE)) {
		Token tk = self.cursor.peek();
		// always a string
		Expr* key;
		switch (tk.kind) {
			case IDENTIFIER:
				key = self.parse_ident_as_string()!;
			case D_QUOTES:
				key = self.parse_str()!;
			default: {
		    	self.fill_diagnostic("expected field name");
            	return ast::INVALID_EXPRESSION~;
			}
		}

        if (!self.cursor.follows(COLON)) {
            self.fill_diagnostic("expected ':' after field name");
            return ast::INVALID_EXPRESSION~;
        }
		Expr* value = self.parse_expression()!;
        fields.push({ key, value });
		
		if (!self.cursor.follows(NEW_LINE)
			&& !self.cursor.follows(COMMA)) break;
	}

	if (!self.cursor.follows(CLOSED_BRACE)) {
        self.fill_diagnostic("expected '}'");
        return ast::INVALID_EXPRESSION~;
    }
	
	return expr::@new(LITERAL,
		{
			.type = Type.RECORD,
			._record = fields
		},
		self.stmt_span(start),
	);
}
fn StringPart? Parser.parse_interp_ident(&self)
{
	self.cursor.advance_check(INTERP_IDENT);

	Expr* ident = self.parse_ident()!;
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

fn StringPart Parser.parse_text(&self)
{
	Token tk = self.cursor.advance_check(TEXT);
	return {
		.kind = TEXT,
		.text = tk.span.slice 	
	};
}

fn Expr*? Parser.parse_str(&self)
{
	Span start = self.cursor.advance_check(D_QUOTES).span;

	String static_str = "";
	List{ StringPart } dyn_str;
	// parts.init(mem);

	while (!self.cursor.follows(D_QUOTES)) {
		StringPart part;
		Token tk = self.cursor.peek();
		
		switch (tk.kind) {
			case TEXT: part = self.parse_text();
			case INTERP_START: part = self.parse_interp()!;	
			case INTERP_IDENT: part = self.parse_interp_ident()!;
			default: unreachable("Unexpected token in string body");
		}

		if (!dyn_str.len() && part.kind == TEXT && !static_str.len) {
			static_str = part.text;
			continue;
		}
		
		if (!dyn_str.len()) {
			// promote to a dynamic string
			dyn_str.init(mem);
			if (static_str.len) {
				dyn_str.push({ .kind = TEXT, .text = static_str });
			}
		}
		
		dyn_str.push(part);
	}

	LiteralString str;
	if (dyn_str.len()) {
		str = { .kind = DYNAMIC, .dyn_str = dyn_str };
	}
	else {
		str = { .kind = STATIC, .static_str = static_str };
	}
	return expr::@new(LITERAL,
		{
			.type = STRING,
			._string = str
		},
		self.stmt_span(start),
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
 		
	return expr::@new(CALL,
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

	return expr::@new(INDEX,
		{ indexed, index },
		self.stmt_span(start)
	);
}

// fn Expr*? Parser.parse_pipe(&self, Expr* left, OperatorDef op_def)
// {
// 	Expr* right = self.parse_expression(op_def.prec)!;

// 	PipeMode mode; switch(op_def.op) {
// 		case PIPE: mode = OUT;
// 		case PIPE_ERR: mode = ERR;
// 		case PIPE_ALL: mode = OUT_ERR;
// 		default: unreachable("Provided operator is not a PIPE");
// 	}

// 	if (left.kind == PIPELINE) {
// 		Pipeline* pipeline = &left.defs.pipeline;
// 		pipeline.links.push({ right, mode });
// 		left.span = left.span.extend(right.span);
// 		return left;
// 	}
	
// 	List{ PipelineLink } links; links.init(mem);
// 	links.push({ right, mode });

// 	return expr::@new(PIPELINE,
// 		{ left, links },
// 		self.stmt_span(left.span.extend(right.span))
// 	);
// }

fn Expr*? Parser.parse_dot_access(&self, Expr* accessed)
{
	Span start = self.cursor.advance_check(DOT).span;

	Token field = self.cursor.advance();

	if (field.kind != IDENTIFIER) {
    	self.fill_diagnostic("expected field name after '.'");
    	return ast::INVALID_EXPRESSION~;
    }
	
   	return expr::@new(FIELD,
    	{ accessed, field.span.slice },
    	self.stmt_span(start)
    );
}

<* [ \n;|})] *>
fn bool is_shell_call_terminator(TokenKind kind)
{
	return is_line_terminator(kind) ||
		// kind == SPACE || // Used for arg terminator
		kind == PIPE ||
		kind == AMP ||
		kind == PIPE_AMP ||
		kind == EXCL_PIPE ||
		kind == CLOSED_BRACE ||
		kind == CLOSED_PARENTHESIS;
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

	return expr::@new(CALL,
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
		//!! TODO: Add parsing of the arg when its just a string without
		// making it parts
		// Also maybe slurp the raw tokens into a single string
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

	// Args are raw strings
	return expr::@new(LITERAL,
		{
			.type = Type.STRING,
			._string = { .kind = DYNAMIC, .dyn_str = parts }
		},
		self.stmt_span(start)
	);
}

fn Expr*? Parser.parse_lambda(&self)
{
	Span start = self.cursor.advance_check(AMP).span;

	if (!self.cursor.follows(OPEN_BRACE)) {
		self.fill_diagnostic("expected '{'");
		return ast::INVALID_EXPRESSION~;				
	}

	List{ TypedIdent } params;
	params.init(mem);

	if (self.cursor.follows(PIPE) && !self.cursor.follows(PIPEX2)) {
		self.parse_parameters(&params)!;
		if (self.cursor.follows(PIPE)) {
			self.fill_diagnostic("expected '|'");
			return ast::INVALID_EXPRESSION~;	
		}
	}

	Expr* body = self.parse_block_body(self.cursor.peek().span)!;
	return expr::@new(LITERAL,
		{
			.type = Type.LAMBDA,
			._lambda = { params, body },
		},
		self.stmt_span(start)
	);
}
