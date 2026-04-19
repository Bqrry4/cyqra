module cyqra::parser;
import std::collections::list;
import std::collections::set;
import std::io;

import cyqra::lexer::token;
import cyqra::diagnostic;
import utils::nullable;

struct Parser
{
	Allocator allocator;

	OperatorDef ops_def;
	Ast ast;
	Namespace* nms;
	
	Cursor cursor;
	Diagnostic diagnostic;
}

fn Parser new(Allocator allocator, Diagnostic diagnostic)
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
	self.diagnostic.msg = msg;
	self.diagnostic.span = self.cursor.expr_span();
	Token cause = self.cursor.peek(skip_wp: false);
	self.diagnostic.line = cause.line;
	self.diagnostic.column = cause.column;
	self.diagnostic.length = cause.slice.len;
	io::printn(cause);
}
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
				case self.cursor.follows(FN): {
					error = @catch(
						@try(expr, self.parse_function())
					);
					if (!error) self.ast.expressions.push(expr);
				}
				case self.cursor.follows(OPEN_BRACE): {
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
			}
		}
	};
}

<* [ \n;|})] *>
fn bool is_shell_call_terminator(TokenKind kind)
{
	switch (kind) {
		case SPACE: case NEW_LINE:     case SEMICOLON:
		case PIPE:  case CLOSED_BRACE: case CLOSED_PHARANTESIS:
		case EOF:
			return true;
		default: return false;
	};
}

fn Expr*? Parser.parse_shell_call(&self, Expr* callee)
{
	List{ Expr* } args;
	args.init(mem);
		
	while (self.cursor.follows(TokenKind.SPACE, skip_wp: false)) {
	
		if (self.cursor.follows(TokenKind.OPEN_PHARANTESIS, skip_lf: false)) {
			args.push(self.parse_expression()!);
			if (!self.cursor.follows(TokenKind.CLOSED_PHARANTESIS)) {
				self.fill_diagnostic("expected ')'");
				return ast::INVALID_EXPRESSION~;
			}
			continue;
		}

		Token tk = self.cursor.peek(skip_lf: false);
		if (is_shell_call_terminator(tk.kind)) break;

		List{ StringPart } parts;
		parts.init(mem);
		// consume tokens greedily until terminator 
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
					Expr* ident = mem::new(Expr, {
						.kind = ExprKind.PRIMARY,
						.primary = {
							.token = tk
						}
					});

					part = {
						.kind = INTERP,
						.interp = ident
					};
				}
				default: part = {
					.kind = TEXT,
					.text = tk.slice 	
				};	
			}
			
			parts.push(part);
			
			tk = self.cursor.peek(skip_wp: false);
		} while (!is_shell_call_terminator(tk.kind));

		args.push(mem::new(Expr, {
			.kind = ExprKind.STRING,
			.string = {
				.parts = parts
			}  
		}));
	}
	
	return mem::new(Expr, {
		.kind = ExprKind.CALL,
		.call = {
			.callee = callee,
			.args = args
		}
	});
}

fn Expr*? Parser.expr_head(&self)
{
	Token tk = self.cursor.advance();

	switch(tk.kind) {
		//& literal
		case INTEGER:
		case FLOAT:
			return mem::new(Expr, {
				.kind = ExprKind.PRIMARY,
				.primary = {
					.token = tk
				}
			});
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
							.text = tk.slice 	
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
			return mem::new(Expr, {
				.kind = ExprKind.STRING,
				.string = {
					.parts = parts
				}  
			});
		}
		//& identifier
		//& shell_call 
		case IDENTIFIER: {
			Expr* primary = mem::new(Expr, {
				.kind = ExprKind.PRIMARY,
				.primary = {
					.token = tk
				}
			});

			if (self.nms.has(tk.slice) ||
				self.cursor.follows(TokenKind.OPEN_PHARANTESIS, consume:false, skip_wp: false)
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
				return mem::new(Expr, {
					.kind = ExprKind.PREFIX,
					.prefix = {
						.op = tk.kind,
						.rhs = rhs 
					}
				});
			}
			// ast::INVALID_EXPRESSION~!!;
			io::printn(tk);
			self.fill_diagnostic("unexpected token");
			return ast::INVALID_EXPRESSION~;
	}
}

fn Expr*? Parser.parse_expression(&self, Precedence base_prec = 0)
{
	Expr* expr = self.expr_head()!;
	//& { expr_tail }
	while (true) {
		Token op = self.cursor.peek(skip_lf: false);

		//& "(" , [ argument_list ] , ")"
		if (op.kind == TokenKind.OPEN_PHARANTESIS) {
			self.cursor.advance();

			List{ Expr* } args;
			args.init(mem);
			
			if (!self.cursor.follows(CLOSED_PHARANTESIS))
        	{
            	do {
                	args.push(self.parse_expression()!);
    	        } while (self.cursor.follows(TokenKind.COMMA));

				if(!self.cursor.follows(CLOSED_PHARANTESIS)) {
					self.fill_diagnostic("expected ')'");
					return ast::INVALID_EXPRESSION~;				
				}
         	}
			
			expr = mem::new(Expr, {
				.kind = ExprKind.CALL,
				.call = {
					.callee = expr,
					.args = args
				}
			});
			continue;
		}
		//& "[" , expression , "]"
		if (op.kind == TokenKind.OPEN_BRACKET) {
			self.cursor.advance();
			
			Expr* index = self.parse_expression()!;
			if(!self.cursor.follows(CLOSED_BRACKET)) {
				self.fill_diagnostic("expected '}'");
				return ast::INVALID_EXPRESSION~;				
			}

			expr = mem::new(Expr, {
            	.kind = ExprKind.INDEX,
            	.index = {
                	.object = expr,
                	.index = index
            	}
        	});
			continue;
		}
		//& postfix_op
		if (try prec = self.ops_def.check_postfix_op(op.kind)) {
			self.cursor.advance();
			
			expr = mem::new(Expr, {
				.kind = ExprKind.POSTFIX,
				.postfix = {
					.lhs = expr,
					.op = op.kind,
				}
			});
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
			expr = mem::new(Expr, {
				.kind = ExprKind.INFIX,
				.infix = {
					.lhs = expr,
					.op = op.kind,
					.rhs = rhs
				}
			});
			continue;
		}
		break;
	}
	return expr;
}


fn Expr*? Parser.parse_binding(&self)
{
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
	if (identifier.kind != TokenKind.IDENTIFIER) {
		self.fill_diagnostic("expected identifier after binding keyword");
		return ast::INVALID_EXPRESSION~;
	}
	if (!self.cursor.follows(TokenKind.EQ)) {
		self.fill_diagnostic("expected =");
		return ast::INVALID_EXPRESSION~;
	}
	
	Expr* value = self.parse_expression()!;
	self.nms.add(identifier.slice.copy(self.allocator));
	
	return mem::new(Expr, {
		.kind = ExprKind.BINDING,
		.binding = {
			.type = LET,
			.identifier = identifier,
			.value = value 
		}
	});
}

//! TODO
fn Expr*? Parser.parse_assignment(&self)
{
	// io::printn("assign not supported");
	return ast::INVALID_EXPRESSION~;
}

fn Expr*? Parser.parse_return(&self)
{
	Nullable{ Expr* } value = nullable::NULL;
	if (try expr = self.parse_expression()) {
		value = nullable::value(expr);
	}

	return mem::new(Expr, {
		.kind = ExprKind.RETURN,
		.ret = {
			.value = value
		}		
	});
}

fn Expr*? Parser.parse_statement(&self)
{
	switch {
		case self.cursor.follows(RETURN): return self.parse_return();
		case self.cursor.follows(LET): return self.parse_binding();
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
			if (self.cursor.follows($vaconst[$i], consume: false)) break;
    	$endfor
		stmts.push(self.parse_statement()!);
    } while (self.cursor.follows(TokenKind.NEW_LINE, skip_lf: false)
		|| self.cursor.follows(TokenKind.SEMICOLON)
	);
}

fn Expr*? Parser.parse_block(&self, Nullable{ Namespace* } nms = nullable::NULL)
{
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

	self.parse_statement_list(&stmts, TokenKind.CLOSED_BRACE)!;
	if (!self.cursor.follows(TokenKind.CLOSED_BRACE)) {
		self.fill_diagnostic("expected '}'");
		return ast::INVALID_EXPRESSION~;
	}

	return mem::new(Expr, {
		.kind = ExprKind.BLOCK,
		.block = {
			.stmts = stmts
		}
	});
}

fn void? Parser.parse_parameters(&self, List{ String }* params)
{
	do {
		Token tk = self.cursor.peek();
		if (tk.kind != TokenKind.IDENTIFIER) {
			self.fill_diagnostic("expected identifier");
			return ast::INVALID_EXPRESSION~;
		}
		self.cursor.advance();
		params.push(tk.slice);
	} while (self.cursor.follows(TokenKind.COMMA));
}

fn Expr*? Parser.parse_function(&self)
{
	Token identifier = self.cursor.advance();
	if (identifier.kind != TokenKind.IDENTIFIER) {
		self.fill_diagnostic("function name not provided");
		return ast::INVALID_EXPRESSION~;
	}

	if (!self.cursor.follows(TokenKind.OPEN_PHARANTESIS)) {
		self.fill_diagnostic("missing '(' after function declaration");
		return ast::INVALID_EXPRESSION~;
	}

	List{ String } params;
	params.init(mem);
	
	if (!self.cursor.follows(TokenKind.CLOSED_PHARANTESIS)) {
		self.parse_parameters(&params)!;

		if (!self.cursor.follows(TokenKind.CLOSED_PHARANTESIS)) {
			self.fill_diagnostic("expected ')'");
			return ast::INVALID_EXPRESSION~;
		}
	}

	if(!self.cursor.follows(OPEN_BRACE)) {
		self.fill_diagnostic("expected block");
		return ast::INVALID_EXPRESSION~;
	}
	
	Namespace* fn_nms = namespace::new_ref(self.allocator, nullable::value(self.nms));
	defer fn_nms.free(self.allocator);

	foreach (param: params) {
		fn_nms.add(param.copy(self.allocator));
	}

	Expr* body = self.parse_block(nullable::value(fn_nms))!;	
	return mem::new(Expr, {
		.kind = ExprKind.FUNCTION,
		.fun = {
			.identifier = identifier,
			.params = params,
			.body = body
		}
	});
}
