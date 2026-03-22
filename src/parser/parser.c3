module cyqra::parser;
import std::collections::list;
import std::collections::enummap;
import std::collections::maybe;
import std::io;

import cyqra::lexer;

alias _Operator_ = Maybe{ Operator };

faultdef OUT_OF_TOKENS;

struct Parser
{
	Allocator allocator;

	//! Make this better later
	EnumMap{ TokenKind, _Operator_ } prefix_ops;
	EnumMap{ TokenKind, _Operator_ } postfix_ops;
	EnumMap{ TokenKind, _Operator_ } infix_ops;

	List{ Token } tokens;
	Ast ast;
	
	uint start;
	uint current;
}

fn Parser new(Allocator allocator, List{ Token } tokens)
{		
	EnumMap{ TokenKind, _Operator_ } prefix_ops;
	prefix_ops.init(maybe::EMPTY);
	EnumMap{ TokenKind, _Operator_ } postfix_ops;
	postfix_ops.init(maybe::EMPTY);
	EnumMap{ TokenKind, _Operator_ } infix_ops;
	infix_ops.init(maybe::EMPTY);

	postfix_ops[OPEN_PHARANTESIS] = maybe::value({15, LEFT});
	postfix_ops[OPEN_BRACKET] = maybe::value({15, LEFT});
	postfix_ops[DOT] = maybe::value({15, LEFT});
	postfix_ops[PLUS_PLUS] = maybe::value({15, LEFT});
	postfix_ops[MINUS_MINUS] = maybe::value({15, LEFT});
	postfix_ops[EXCLAMATION] = maybe::value({16, LEFT});

	prefix_ops[PLUS] = maybe::value({14, RIGHT});
	prefix_ops[MINUS] = maybe::value({14, RIGHT});
	prefix_ops[PLUS_PLUS] = maybe::value({14, RIGHT});
	prefix_ops[MINUS_MINUS] = maybe::value({14, RIGHT});
	prefix_ops[EXCLAMATION] = maybe::value({14, RIGHT});


	infix_ops[STAR_STAR] = maybe::value({13, LEFT});
	infix_ops[STAR] = maybe::value({12, LEFT});
	infix_ops[SLASH] = maybe::value({12, LEFT});
	infix_ops[PERCENT] = maybe::value({12, LEFT});
	infix_ops[PLUS] = maybe::value({11, LEFT});
	infix_ops[MINUS] = maybe::value({11, LEFT});

	Ast ast = ast::new(allocator);

	return {
		.allocator = allocator,
		.tokens = tokens,
		.ast = ast,
		.prefix_ops = prefix_ops,
		.postfix_ops = postfix_ops,
		.infix_ops = infix_ops
	};
}

fn void Parser.free(&self)
{
	//!TODO
}

fn Token? Parser.advance(&self, bool skip_spaces = true)
{
	if (skip_spaces) self.skip_spaces();		
	if (self.eot()) return OUT_OF_TOKENS~;
	return (self.tokens[self.current++]);
} 
fn Token? Parser.peek(&self, bool skip_spaces = true)
{
	if (skip_spaces) self.skip_spaces();
	if(self.eot()) return OUT_OF_TOKENS~;
	return (self.tokens[self.current]);
}
fn bool Parser.eot(&self) => self.current >= self.tokens.len(); 
fn bool? Parser.follows(&self, TokenKind expect, bool skip_spaces = true)
{
	if(skip_spaces) self.skip_spaces();
	return (self.peek()!.kind == expect) && ++self.current;
} 
fn void Parser.skip_spaces(&self)
{
	while (!self.eot() &&
		 (self.tokens[self.current].kind == TokenKind.SPACE ||
		  self.tokens[self.current].kind == TokenKind.NEW_LINE)) {
			self.current++;
		};
}
fn void Parser.parse(&self)
{
	mem::@scoped(self.allocator)
	{
		while(!self.eot())
		{
			if (try expr = self.parse_block()) {
				self.ast.expressions.push(expr);
				continue;	
			}
			
			if (try expr = self.parse_function()) {
				self.ast.expressions.push(expr);
				continue;		
			}

			if (try expr = self.parse_statement()) {
				self.ast.expressions.push(expr);
				continue;
			}
		}
	};
	
}

//! Needs refactoring
fn Precedence? Parser.check_prefix_op(&self, TokenKind tk)
{
	_Operator_ maybe_op = self.prefix_ops[tk];
	if (!maybe_op.has_value) return NOT_FOUND~;
	Operator op = maybe_op.value;
	return op.prec;
}

fn Precedence? Parser.check_postfix_op(&self, TokenKind tk)
{
	_Operator_ maybe_op = self.postfix_ops[tk];
	if (!maybe_op.has_value) return NOT_FOUND~;
	Operator op = maybe_op.value;
	return op.prec;
}

fn Precedence? Parser.check_infix_op(&self, TokenKind tk, Precedence prec)
{
	_Operator_ maybe_op = self.infix_ops[tk];
	if (!maybe_op.has_value) return NOT_FOUND~;
	
	Operator op = maybe_op.value;
	bool is_higher = op.prec > prec;
	bool is_right = op.as == Associativity.RIGHT;
	bool is_equal = op.prec == prec;

	if (is_higher || (is_right && is_equal)) {
		return op.prec;	
	}
	
	return NOT_FOUND~;
}


//! TBD
fn Expr*? Parser.parse_shell_call(&self, Token tk)
{

	List{ Expr* } args;
	args.init(mem);
	
	while (self.follows(TokenKind.SPACE, false)!) {
		
		if (self.follows(TokenKind.OPEN_PHARANTESIS)!)
		{
			args.push(self.parse_expression()!);

			if(!self.follows(TokenKind.CLOSED_PHARANTESIS)!) {
				return ast::INVALID_EXPRESSION~;
			}

			continue;
		}

		//if a terminator, break, else push the token 
	
			
	}
	
	// return mem::new(Expr, {
	// 	.kind = ExprKind.CALL,
	// 	.call = {
	// 		.callee = expr,
	// 		.args = args
	// 	}
	// });
	return ast::INVALID_EXPRESSION~;
}


fn Expr*? Parser.expr_head(&self)
{
	Token tk = self.advance()!;

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

			while (!self.follows(D_QUOTES)!) {
				StringPart part;
				tk = self.advance()!;

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
						if (!self.follows(INTERP_END)!) {
							io::printn("Was expecting Close bracket");
							return ast::INVALID_EXPRESSION~;			
						}
					case INTERP_IDENT:
						part = {
							.kind = INTERP,
							.interp = self.parse_expression()!
						};
					default: unreachable("Unexpected token in string body");
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
		case IDENTIFIER:
			if(true) /* !is_inscope */ {
				return mem::new(Expr, {
					.kind = ExprKind.PRIMARY,
					.primary = {
						.token = tk
					}
				});
			}
	
			return self.parse_shell_call(tk);							
		//& sub_expression 
		case OPEN_PHARANTESIS:
			Expr* expr = self.parse_expression()!;
			if(!self.follows(CLOSED_PHARANTESIS)!)
			{
				io::printn("Was expecting Closed pharantesis");
				return ast::INVALID_EXPRESSION~;
			}	
			return expr;
		default:
			//& prefix_op , expression
			if(try prec = self.check_prefix_op(tk.kind))
			{
				Expr* rhs = self.parse_expression(prec)!;
				return mem::new(Expr, {
					.kind = ExprKind.PREFIX,
					.prefix = {
						.op = tk.kind,
						.rhs = rhs 
					}
				});
			}	
						
			return ast::INVALID_EXPRESSION~;
	}
}

fn Expr*? Parser.parse_expression(&self, Precedence base_prec = 0)
{
	Expr* expr = self.expr_head()!;
	//& { expr_tail }
	while (try op = self.peek()) {
		//& "(" , [ argument_list ] , ")"
		if (op.kind == TokenKind.OPEN_PHARANTESIS) {
			self.advance()!;

			List{ Expr* } args;
			args.init(mem);


			if (!self.follows(CLOSED_PHARANTESIS)!)
        	{
            	do {
                	args.push(self.parse_expression()!);
    	        } while (self.follows(TokenKind.COMMA)!);

				if(!self.follows(CLOSED_PHARANTESIS)!) {
					io::printn("Was expecting Close pharantesis");
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
			self.advance()!;
			
			Expr* index = self.parse_expression()!;
			if(!self.follows(CLOSED_BRACKET)!) {
				io::printn("Was expecting Close bracket");
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
		if (try prec = self.check_postfix_op(op.kind)) {
			self.advance()!;
			
			expr = mem::new(Expr, {
				.kind = ExprKind.POSTFIX,
				.postfix = {
					.lhs = expr,
					.op = op.kind,
				}
			});
			continue;	
		}
		//& infix_op , expression
		if (try prec = self.check_infix_op(op.kind, base_prec)) {
			self.advance()!;
			
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
	TokenKind binding_type = self.peek()!.kind;
	switch(binding_type) {
		case LET..ENV:
			self.advance()!;
		default:
			// io::printn("No binding keyword");
			return ast::INVALID_EXPRESSION~; 
	}

	Token identifier = self.advance()!;
	if(identifier.kind != TokenKind.IDENTIFIER) {
		io::printn("Identifier missing after binding");
		return ast::INVALID_EXPRESSION~;
	}

	if(!self.follows(TokenKind.EQ)!) {
		io::printn("= missing after binding");
		return ast::INVALID_EXPRESSION~;
	}

	Expr* value = self.parse_expression()!;
	
	return mem::new(Expr, {
		.kind = ExprKind.BINDING,
		.binding = {
			.type = binding_type,
			.identifier = identifier,
			.value = value 
		}
	});
}

fn Expr*? Parser.parse_assignment(&self)
{
	return ast::INVALID_EXPRESSION~;
}

fn Expr*? Parser.parse_statement(&self)
{
	if(try binding = self.parse_binding()) {
		return binding;
	}	

	if(try assignment = self.parse_assignment()) {
		return assignment;
	}

	return self.parse_expression();
}


fn Expr*? Parser.parse_block(&self)
{
	
	if(!self.follows(TokenKind.OPEN_BRACE)!) {
		// io::printn("No {");
		return ast::INVALID_EXPRESSION~;
	}

	List{ Expr* } stmts;
	stmts.init(mem);
    

	if(!self.follows(TokenKind.CLOSED_BRACE)!) {
	 	do {
          	stmts.push(self.parse_statement()!);
        } while (self.follows(TokenKind.SEMICOLON)!);

		
		if(!self.follows(TokenKind.CLOSED_BRACE)!) {
			// io::printn("No }");
			return ast::INVALID_EXPRESSION~;
		}
	}
	
	return mem::new(Expr, {
		.kind = ExprKind.BLOCK,
		.block = {
			.stmts = stmts
		}
	});
}

fn void? Parser.parse_parameters(&self, List{ Token }* params)
{
	do {
		Token tk = self.peek()!;
		if(tk.kind != TokenKind.IDENTIFIER) {
			return ast::INVALID_EXPRESSION~;
		}
		self.advance()!;
		params.push(tk);
	} while (self.follows(TokenKind.COMMA)!);
}

fn Expr*? Parser.parse_function(&self)
{
	if(!self.follows(TokenKind.FN)!) {
		// io::printn("Not a function");
		return ast::INVALID_EXPRESSION~;
	}
	
	Token identifier = self.advance()!;
	if(identifier.kind != TokenKind.IDENTIFIER) {
		io::printn("Function name missing");
		return ast::INVALID_EXPRESSION~;
	}

	if(!self.follows(TokenKind.OPEN_PHARANTESIS)!) {
		io::printn("No (");
		return ast::INVALID_EXPRESSION~;
	}

	List{ Token } params;
	params.init(mem);
	
	if(!self.follows(TokenKind.CLOSED_PHARANTESIS)!) {
		self.parse_parameters(&params)!;

		if(!self.follows(TokenKind.CLOSED_PHARANTESIS)!) {
			io::printn("No )");
			return ast::INVALID_EXPRESSION~;
		}
	}
	
	Expr* body = self.parse_block()!;	
	
	return mem::new(Expr, {
		.kind = ExprKind.FUNCTION,
		.fun = {
			.identifier = identifier,
			.params = params,
			.body = body
		}
	});
}
