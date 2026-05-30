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
	VarPool vpool;
	Namespace nms;
	
	Cursor cursor;
	Diagnostic* diagnostic;
}

fn Parser new(Allocator allocator, Diagnostic* diagnostic)
{
	Ast ast = ast::new(allocator);
	VarPool vpool = varpool::new(allocator);
	Namespace nms = namespace::new(allocator);
	nms.enter();
	return {
		.allocator = allocator,
		.vpool = vpool,
		.nms = nms,
		.diagnostic = diagnostic
	};
}

fn void Parser.free(&self)
{
	self.nms.leave();
	self.nms.free();
	self.vpool.free();
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

fn VarID Parser.define_variable(&self, String name)
{
	VarID id = self.vpool.push(name);
	// Borrow the value from the pool with it's id
	self.nms.add(self.vpool.name_of(id), id);
	return id;
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
	VarID id = self.define_variable(identifier.span.slice);
	
	return expr::@new(Binding,
		{ LET, id, value },
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

	return expr::@new(Block,
		{ stmts },
		self.stmt_span(start)
	);
}



fn Expr*? Parser.parse_block(&self)
{
	Span start = self.cursor.advance().span;

	self.nms.enter();
	defer self.nms.leave();
	
	return self.parse_block_body(start);
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

fn Expr*? Parser.parse_function_body(&self, List{ String } params)
{
	self.nms.enter();
	defer self.nms.leave();
	
	foreach (param: params) {
		self.define_variable(param);
	}
	
	return self.parse_block_body(self.cursor.peek().span);
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

	if(!self.cursor.follows(OPEN_BRACE)) {
		self.fill_diagnostic("expected '{'");
		return ast::INVALID_EXPRESSION~;
	}
	
	Expr* body = self.parse_function_body(params)!;
	return expr::@new(Function,
		{ identifier, params, body },
		self.stmt_span(start)
	);
}
