module cyqra::parser;
import std::collections::list;
import std::collections::set;
import std::io;

import cyqra::ast;
import cyqra::lexer::token;
import cyqra::lexer::span;
import cyqra::diagnostic;
import utils::nullable;

struct Parser
{
	Allocator alloc;

	Ast ast;
	
	Cursor cursor;
	Diagnostic* diagnostic;

	List{ Function* } fn_decl;
}

fn Parser new(Allocator alloc, Diagnostic* diagnostic)
{
	Ast ast = ast::new(alloc);
	List{ Function* } fn_decl; fn_decl.init(alloc);
	
	return {
		.alloc = alloc,
		.diagnostic = diagnostic,
		.fn_decl = fn_decl
	};
}

fn void Parser.free(&self)
{
	self.ast.free();
}

fn void Parser.fill_diagnostic(&self, String msg)
{
	Token cause = self.cursor.peek(RAW);
	self.diagnostic.cause = cause.span;

	self.diagnostic.error(cause.span,
		msg
	);
}

macro Span Parser.stmt_span(&self,
	Span start
) => start.extend(self.cursor.peek(RAW).span);

<*
	Tokens -> Ast.
	@param [in] tokens
*>
fn void Parser.parse(&self, Token[] tokens)
{
	self.cursor.tokens = tokens;
	self.cursor.reset();
	self.ast.clear();

	mem::@scoped(self.alloc)
	{
		while(!self.cursor.eot()) {
			Expr* expr;
			fault error;

			switch {
			case self.cursor.match(EOF): break;
			// top level
			case self.cursor.match(FN):
				error = @catch(
					@try(expr, self.parse_function())
				);
				if (!error) self.ast.expressions.push(expr);
			default:
				error = @catch(
					@try(expr, self.parse_statement())
				);
				if (!error) self.ast.expressions.push(expr);
			}
				
			if(error == ast::INVALID_EXPRESSION) {
				io::printn(self.diagnostic);
				break;
			}
		}
	};
}



fn bool is_line_terminator(TokenKind kind)
{
	return kind == NEW_LINE ||
		kind == SEMICOLON ||
		kind == EOF;
}

fn Expr* Parser.parse_type_annotation(&self)
{
	Token ident = self.cursor.advance_check(IDENTIFIER);
	return expr::@new(IDENTIFIER,
		{ ident.span.slice },
		ident.span
	);
}

<*
	Parses the <ident : type_expr> phrase.
*>
fn TypedIdent? Parser.parse_typed_ident(&self) @inline
{
	Token identifier = self.cursor.advance();
	if (identifier.kind != IDENTIFIER) {
		self.fill_diagnostic("expected identifier");
		return ast::INVALID_EXPRESSION~;
	}
	Identifier id = { identifier.span.slice };

	Nullable{ Expr* } type = nullable::NULL;
	if (self.cursor.follows(COLON)) {
		type = nullable::value(self.parse_type_annotation());
	}
	return { id, type };
}

fn Expr*? Parser.parse_binding(&self)
{
	Span start = self.cursor.advance().span;
	//!Support only let for now
	// add other types as the interpreter matures

	// TokenKind binding_type = self.cursor.peek().kind;
	// switch (binding_type) {
	// 	case LET..ENV:
	// 		self.cursor.advance();
	// 	default:
	// 		return ast::INVALID_EXPRESSION~; 
	// }
	TypedIdent ti = self.parse_typed_ident()!;

	if (!self.cursor.follows(EQ)) {
		self.fill_diagnostic("expected '='");
		return ast::INVALID_EXPRESSION~;
	}

	if (is_line_terminator(self.cursor.peek(KEEP_SEP).kind)) {
		self.fill_diagnostic("missing expression following '='");
		return ast::INVALID_EXPRESSION~;
	}
		
	Expr* value = self.parse_expression()!;
	return expr::@new(BINDING,
		{ /*LET,*/ ti, value },
		self.stmt_span(start)
	);
}

fn Expr*? Parser.parse_return(&self)
{
	Span start = self.cursor.peek(RAW).span;

	Nullable{ Expr* } value = nullable::NULL;
	if (!is_line_terminator(self.cursor.peek(KEEP_SEP).kind)) {
		value = nullable::value(
			self.parse_expression()!
		);
	}

	return expr::@new(RETURN,
		{ value },
		self.stmt_span(start)
	);
}

fn Expr*? Parser.parse_statement(&self)
{
	switch {
		case self.cursor.match(RETURN): return self.parse_return();
		case self.cursor.match(LET): return self.parse_binding();
		default: return self.parse_expression();
	}
}

<*
	@param [&inout] stmts
	@param ... : "Provide additional terminator"
*>
macro void? Parser.parse_statement_list(&self, List{ Expr* }* stmts, ...)
{
	do {
	    $for var $i = 0; $i < $vaarg.len; $i++:
			if (self.cursor.match($vaarg[$i])) break;
    	$endfor
		stmts.push(self.parse_statement()!);
    } while (self.cursor.follows(NEW_LINE)
		|| self.cursor.follows(SEMICOLON)
	);
}

fn Expr*? Parser.parse_block_body(&self, Span start)
{
	List{ Expr* } stmts; stmts.init(mem);
	self.parse_statement_list(&stmts, CLOSED_BRACE)!;

	if (!self.cursor.follows(CLOSED_BRACE)) {
	
	io::printn(self.cursor.peek());
		self.fill_diagnostic("expected '}'");
		return ast::INVALID_EXPRESSION~;
	}

	return expr::@new(SEQUENCE, stmts,
		self.stmt_span(start)
	);
}

fn Expr*? Parser.parse_block(&self)
{
	Span start = self.cursor.advance().span;
	return self.parse_block_body(start);
}

fn void? Parser.parse_parameters(&self, List{ TypedIdent }* params)
{
	do {
		params.push(
			self.parse_typed_ident()!
		);
	} while (self.cursor.follows(COMMA));
}

fn Expr*? Parser.parse_function(&self)
{
	Span start = self.cursor.advance().span;
	
	Token identifier = self.cursor.advance();
	if (identifier.kind != IDENTIFIER) {
		self.fill_diagnostic("function name not provided");
		return ast::INVALID_EXPRESSION~;
	}
	String name = identifier.span.slice;
	
	if (!self.cursor.follows(OPEN_PARENTHESIS)) {
		self.fill_diagnostic("missing '(' after function declaration");
		return ast::INVALID_EXPRESSION~;
	}

	List{ TypedIdent } params;
	params.init(mem);
	
	if (!self.cursor.follows(CLOSED_PARENTHESIS)) {
		self.parse_parameters(&params)!;

		if (!self.cursor.follows(CLOSED_PARENTHESIS)) {
			self.fill_diagnostic("expected ')'");
			return ast::INVALID_EXPRESSION~;
		}
	}

	Nullable{ Expr* } type = nullable::NULL;
	if (self.cursor.follows(COLON)) {
		type = nullable::value(self.parse_type_annotation());
	}
	TypedIdent ti = { { name }, type };
	
	if(!self.cursor.follows(OPEN_BRACE)) {
		self.fill_diagnostic("expected '{'");
		return ast::INVALID_EXPRESSION~;
	}
	
	Expr* body = self.parse_block_body(self.cursor.peek().span)!;
	Expr* fun = expr::@new(FUNCTION,
		{ ti, params, body },
		self.stmt_span(start)
	);

	self.fn_decl.push(&fun.defs.fun);
	return fun;
}
