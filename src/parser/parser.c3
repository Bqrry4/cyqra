module cyqra::parser;
import std::collections::list;
import std::collections::set;
import std::io;

import cyqra::lexer::token;
import cyqra::lexer::span;
import cyqra::diagnostic;
import utils::nullable;

struct Parser
{
	Allocator allocator;

	Ast ast;
	Namespace* nms;
	
	Cursor cursor;
	Diagnostic* diagnostic;
}

fn Parser new(Allocator allocator, Diagnostic* diagnostic)
{
	Ast ast = ast::new(allocator);
	Namespace* nms = namespace::new_ref(allocator);
	return {
		.allocator = allocator,
		.nms = nms,
		.diagnostic = diagnostic
	};
}

fn void Parser.free(&self)
{
	self.nms.free(self.allocator);
	alloc::free(self.allocator, self.nms);
	//! TODO: the rest
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
	@param tokens
*>
fn void Parser.parse(&self, List{ Token } tokens)
{
	self.cursor.tokens = tokens;
	self.cursor.reset();
	self.ast.clear();

	mem::@scoped(self.allocator)
	{
		while(!self.cursor.eot()) {
			Expr* expr;
			fault error;
			switch {
				case self.cursor.match(EOF): break;
				// top level
				case self.cursor.match(FN): {
					error = @catch(
						@try(expr, self.parse_function())
					);
					if (!error) self.ast.expressions.push(expr);
				}
				default: {
					error = @catch(
						@try(expr, self.parse_statement())
					);
					if (!error) self.ast.expressions.push(expr);
				}
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

	Token identifier = self.cursor.advance();
	if (identifier.kind != IDENTIFIER) {
		self.fill_diagnostic("expected identifier after binding keyword");
		return ast::INVALID_EXPRESSION~;
	}

	if (!self.cursor.follows(EQ)) {
		self.fill_diagnostic("expected '='");
		return ast::INVALID_EXPRESSION~;
	}

	if (is_line_terminator(self.cursor.peek(KEEP_SEP).kind)) {
		self.fill_diagnostic("missing expression following '='");
		return ast::INVALID_EXPRESSION~;
	}
		
	Expr* value = self.parse_expression()!;
	self.nms.add(identifier.span.slice.copy(self.allocator));
	
	return expr::@new(Binding,
		{ LET, identifier, value },
		self.stmt_span(start)
	);
}

//! TODO
fn Expr*? Parser.parse_assignment(&self)
{
	// io::printn("assign not supported");
	return ast::INVALID_EXPRESSION~;
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

	return expr::@new(Return,
		{ value },
		self.stmt_span(start)
	);
}

fn Expr*? Parser.parse_statement(&self)
{
	switch {
		case self.cursor.match(RETURN): return self.parse_return();
		case self.cursor.match(LET): return self.parse_binding();
		case self.cursor.match(OPEN_BRACE): return self.parse_block();
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

fn Expr*? Parser.parse_block(&self,
	Nullable{ Namespace* } nms = nullable::NULL
){
	Span start = self.cursor.advance().span;

	Namespace* local_nms = nms.ptr;
	// Create an owned nms if not provided
	bool owned = nms.is_null();
	if (owned) {
		local_nms = namespace::new_ref(
			self.allocator, nullable::value(self.nms)
		);
	}
	defer if (owned) {	
		local_nms.free(self.allocator);
		alloc::free(self.allocator, local_nms);
	}

	self.nms = local_nms;
	defer {
		self.nms = local_nms.parent.ptr;
	};
	
	List{ Expr* } stmts; stmts.init(mem);

	self.parse_statement_list(&stmts, CLOSED_BRACE)!;
	if (!self.cursor.follows(CLOSED_BRACE)) {
		self.fill_diagnostic("expected '}'");
		return ast::INVALID_EXPRESSION~;
	}

	return expr::@new(Block,
		{ stmts },
		self.stmt_span(start)
	);
}

fn void? Parser.parse_parameters(&self, List{ String }* params)
{
	do {
		Token tk = self.cursor.peek();
		if (tk.kind != IDENTIFIER) {
			self.fill_diagnostic("expected identifier");
			return ast::INVALID_EXPRESSION~;
		}
		self.cursor.advance();
		params.push(tk.span.slice);
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

	if (!self.cursor.follows(OPEN_PARENTHESIS)) {
		self.fill_diagnostic("missing '(' after function declaration");
		return ast::INVALID_EXPRESSION~;
	}

	List{ String } params;
	params.init(mem);
	
	if (!self.cursor.follows(CLOSED_PARENTHESIS)) {
		self.parse_parameters(&params)!;

		if (!self.cursor.follows(CLOSED_PARENTHESIS)) {
			self.fill_diagnostic("expected ')'");
			return ast::INVALID_EXPRESSION~;
		}
	}

	if(!self.cursor.match(OPEN_BRACE)) {
		self.fill_diagnostic("expected block");
		return ast::INVALID_EXPRESSION~;
	}
	
	Namespace* fn_nms = namespace::new_ref(self.allocator, nullable::value(self.nms));
	defer {
		fn_nms.free(self.allocator);
		alloc::free(self.allocator, fn_nms);
	}

	foreach (param: params) {
		fn_nms.add(param.copy(self.allocator));
	}

	Expr* body = self.parse_block(nullable::value(fn_nms))!;
	return expr::@new(Function,
		{ identifier, params, body },
		self.stmt_span(start)
	);
}
