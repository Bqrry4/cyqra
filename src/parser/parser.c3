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

	OperatorDef ops_def;
	Ast ast;
	Namespace* nms;
	
	Cursor cursor;
	Diagnostic* diagnostic;
}

fn Parser new(Allocator allocator, Diagnostic* diagnostic)
{
	OperatorDef ops_def = op::new();
	Ast ast = ast::new(allocator);
	Namespace* nms = namespace::new_ref(allocator);
	return {
		.allocator = allocator,
		.nms = nms,
		.ops_def = ops_def,
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
				case self.cursor.match(FN): {
					error = @catch(
						@try(expr, self.parse_function())
					);
					if (!error) self.ast.expressions.push(expr);
				}
				case self.cursor.match(OPEN_BRACE): {
					error = @catch(
						@try(expr, self.parse_block())
					);
					if (!error) self.ast.expressions.push(expr);
				}
				
				default: {
					error = @catch(
						self.parse_statement_list(&self.ast.expressions)
					);
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

<* [ \n;|})] *>
fn bool is_shell_call_terminator(TokenKind kind)
{
	return is_line_terminator(kind) ||
		kind == SPACE ||
		kind == PIPE ||
		kind == CLOSED_BRACE ||
		kind == CLOSED_PHARANTESIS ||
		kind == EOF;
}

fn Expr*? Parser.parse_shell_call(&self, Expr* callee)
{
	Span start = self.cursor.peek(RAW).span;
	
	List{ Expr* } args;
	args.init(mem);
		
	while (self.cursor.follows(SPACE)) {

		Token tk = self.cursor.peek(KEEP_LF);
		if (is_shell_call_terminator(tk.kind)) break;

		if (self.cursor.follows(OPEN_PHARANTESIS)) {
			args.push(self.parse_expression()!);
			if (!self.cursor.follows(CLOSED_PHARANTESIS)) {
				self.fill_diagnostic("expected ')'");
				return ast::INVALID_EXPRESSION~;
			}
			continue;
		}

		List{ StringPart } parts;
		parts.init(mem);
		//@ consume tokens greedily until terminator 
		do {
			self.cursor.advance();
			StringPart part;
			switch (tk.kind) {
				case INTERP_START: {
					part = {
						.kind = INTERP,
						.interp = self.parse_expression()! 
					};
					if (!self.cursor.follows(INTERP_END)) {
						self.fill_diagnostic("expected ']'");
						return ast::INVALID_EXPRESSION~;			
					}
				}
				case INTERP_IDENT: {
					tk = self.cursor.advance();
					if (tk.kind != IDENTIFIER) {
						self.fill_diagnostic("expected identifier");
						return ast::INVALID_EXPRESSION~;	
					}
					Expr* ident = expr::@new(Primary,
						{ .token = tk },
						self.stmt_span(start)
					);
					part = {
						.kind = INTERP,
						.interp = ident
					};
				}
				default: part = {
					.kind = TEXT,
					.text = tk.span.slice 	
				};	
			}
			
			parts.push(part);
			
			tk = self.cursor.peek(RAW);
		} while (!is_shell_call_terminator(tk.kind));

		args.push(expr::@new(StringLit,
			{ parts },
			self.stmt_span(start)
		));
	}
	
	return expr::@new(Call,
		{ callee, args },
		self.stmt_span(start)
	);
}

fn Expr*? Parser.expr_head(&self)
{
	Span start = self.cursor.peek(RAW).span;

	Token tk = self.cursor.advance();
	switch(tk.kind) {
		//& literal
		case INTEGER:
		case FLOAT:
			return expr::@new(Primary,
				{ .token = tk },
				self.stmt_span(start)
			);
		case D_QUOTES: {
			List{ StringPart } parts;
			parts.init(mem);

			while (!self.cursor.follows(D_QUOTES)) {
				StringPart part;
				tk = self.cursor.advance();
				
				switch (tk.kind) {
					case STRING_PART:
						part = {
							.kind = TEXT,
							.text = tk.span.slice 	
						};
					case INTERP_START:
						part = {
							.kind = INTERP,
							.interp = self.parse_expression()! 
						};
						if (!self.cursor.follows(INTERP_END)) {
							self.fill_diagnostic("expected '}'");
							return ast::INVALID_EXPRESSION~;			
						}
					//TODO parse only identifier
					case INTERP_IDENT:
						part = {
							.kind = INTERP,
							.interp = self.parse_expression()!
						};
					default:
						unreachable("Unexpected token in string body");
				}
				parts.push(part);
			}
			return expr::@new(StringLit,
				{ parts },
				self.stmt_span(start)
			);
		}
		//& identifier
		//& shell_call 
		case IDENTIFIER: {
			Expr* primary = expr::@new(Primary,
				{ .token = tk },
				self.stmt_span(start)
			);

			if (self.nms.has(tk.span.slice) ||
				self.cursor.match(OPEN_PHARANTESIS, RAW)
			) return primary;

			return self.parse_shell_call(primary);
		}	
		//& sub_expression 
		case OPEN_PHARANTESIS:
			Expr* expr = self.parse_expression()!;
			if(!self.cursor.follows(CLOSED_PHARANTESIS)) {
				self.fill_diagnostic("expected ')'");
				return ast::INVALID_EXPRESSION~;
			}	
			return expr;
		default:
			//& prefix_op , expression
			if(try prec = self.ops_def.check_prefix_op(tk.kind)) {
				Expr* rhs = self.parse_expression(prec)!;
				return expr::@new(Prefix,
					{ .op = tk.kind, .rhs = rhs },
					self.stmt_span(start)
				);
			}
			// ast::INVALID_EXPRESSION~!!;
			io::printn(tk);
			self.fill_diagnostic("unexpected token");
			return ast::INVALID_EXPRESSION~;
	}
}

fn Expr*? Parser.parse_expression(&self, Precedence base_prec = 0)
{
	Span start = self.cursor.peek(RAW).span;

	Expr* expr = self.expr_head()!;
	//& { expr_tail }
	while (true) {
		Token op = self.cursor.peek(KEEP_LF);

		//& "(" , [ argument_list ] , ")"
		if (op.kind == OPEN_PHARANTESIS) {
			self.cursor.advance();

			List{ Expr* } args;
			args.init(mem);
			
			if (!self.cursor.follows(CLOSED_PHARANTESIS))
        	{
            	do {
                	args.push(self.parse_expression()!);
    	        } while (self.cursor.follows(COMMA));

				if(!self.cursor.follows(CLOSED_PHARANTESIS)) {
					self.fill_diagnostic("expected ')'");
					return ast::INVALID_EXPRESSION~;				
				}
         	}
			
			expr = expr::@new(Call,
				{ expr, args },
				self.stmt_span(start)
			);
			continue;
		}
		//& "[" , expression , "]"
		if (op.kind == OPEN_BRACKET) {
			self.cursor.advance();
			
			Expr* index = self.parse_expression()!;
			if(!self.cursor.follows(CLOSED_BRACKET)) {
				self.fill_diagnostic("expected '}'");
				return ast::INVALID_EXPRESSION~;				
			}

			expr = expr::@new(Index,
				{ expr, index },
				self.stmt_span(start)
			);
			continue;
		}
		//& postfix_op
		if (try prec = self.ops_def.check_postfix_op(op.kind)) {
			self.cursor.advance();
			
			expr = expr::@new(Postfix,
				{ expr, op.kind },
				self.stmt_span(start)
			);
			continue;	
		}

		//! TODO: Check for a possible continuation "\",
		// when present skip it and continue the expression,
		// otherwise lookahead for permitted ops with implicit continuation, like (&&, ||) 
		if (op.kind == NEW_LINE) {
			//self.skip_spaces(skip_lf: true);
			
		}
		
		//& infix_op , expression
		if (try prec = self.ops_def.check_infix_op(op.kind, base_prec)) {
			self.cursor.advance();
			
			Expr* rhs = self.parse_expression(prec)!;
			expr = expr::@new(Infix,
				{ expr, op.kind, rhs },
				self.stmt_span(start)
			);
			continue;
		}
		break;
	}
	return expr;
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

	if (is_line_terminator(self.cursor.peek(RAW).kind)) {
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
	if (try expr = self.parse_expression()) {
		value = nullable::value(expr);
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
		default: {
			// if (try assignment = self.parse_assignment()) {
				// return assignment;
			// }

			return self.parse_expression();
		}
	}
}

<*
	@param [&inout] stmts
	@param ... : "Provide additional terminator"
*>
macro void? Parser.parse_statement_list(&self, List{ Expr* }* stmts, ...)
{
	do {
	    $for var $i = 0; $i < $vacount; $i++:
			if (self.cursor.match($vaconst[$i])) break;
    	$endfor
		stmts.push(self.parse_statement()!);
    } while (self.cursor.follows(NEW_LINE)
		|| self.cursor.follows(SEMICOLON)
	);
}

fn Expr*? Parser.parse_block(&self, Nullable{ Namespace* } nms = nullable::NULL)
{
	Span start = self.cursor.advance().span;

	Namespace* local_nms = nms.ptr;
	if(nms.is_null()) {
		local_nms = namespace::new_ref(self.allocator, nullable::value(self.nms));
		defer {
			local_nms.free(self.allocator);
			alloc::free(self.allocator, local_nms);
		}
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

	if (!self.cursor.follows(OPEN_PHARANTESIS)) {
		self.fill_diagnostic("missing '(' after function declaration");
		return ast::INVALID_EXPRESSION~;
	}

	List{ String } params;
	params.init(mem);
	
	if (!self.cursor.follows(CLOSED_PHARANTESIS)) {
		self.parse_parameters(&params)!;

		if (!self.cursor.follows(CLOSED_PHARANTESIS)) {
			self.fill_diagnostic("expected ')'");
			return ast::INVALID_EXPRESSION~;
		}
	}

	if(!self.cursor.match(OPEN_BRACE)) {
		self.fill_diagnostic("expected block");
		return ast::INVALID_EXPRESSION~;
	}
	
	Namespace* fn_nms = namespace::new_ref(self.allocator, nullable::value(self.nms));
	defer fn_nms.free(self.allocator);

	foreach (param: params) {
		fn_nms.add(param.copy(self.allocator));
	}

	Expr* body = self.parse_block(nullable::value(fn_nms))!;
	return expr::@new(Function,
		{ identifier, params, body },
		self.stmt_span(start)
	);
}
