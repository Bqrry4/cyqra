module cyqra::parser;
import std::collections::list;
import std::collections::enummap;
import std::collections::maybe;
import std::io;

import cyqra::lexer;

alias _Operator_ = Maybe{ Operator };

struct Parser
{
	Allocator allocator;

	//! Make this better later
	EnumMap{ TokenKind, _Operator_ } prefix_ops;
	EnumMap{ TokenKind, _Operator_ } postfix_ops;
	EnumMap{ TokenKind, _Operator_ } infix_ops;
	List{ Token } tokens;

	int start;
	int current;
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

	return {
		.allocator = allocator,
		.tokens = tokens,
		.prefix_ops = prefix_ops,
		.postfix_ops = postfix_ops,
		.infix_ops = infix_ops
	};
}

fn void Parser.free(&self)
{
	//!TODO
}

faultdef OUT_OF_TOKENS;

<* Returns the token currently pointed by the @current, then inc it *>
fn Token? Parser.advance(&self)
{
	if(self.eot()) return OUT_OF_TOKENS~;
	return (self.tokens[self.current++]);
} 
<* Checks the next *>
fn Token? Parser.peek(&self)
{
	if(self.eot()) return OUT_OF_TOKENS~;
	return (self.tokens[self.current]);
}
fn bool Parser.eot(&self) => self.current >= self.tokens.len(); 
<* *>
fn bool? Parser.follows(&self, TokenKind expect) => (self.peek()!.kind == expect) && self.current++;

fn void Parser.parse(&self)
{
	mem::@scoped(self.allocator)
	{
		while(self.current < self.tokens.len())
		{

			Expr*? a = self.parse_expression();
			if(catch b = a)
			{
				switch(b)
				{
					case OUT_OF_TOKENS:
						io::printn("Unexpected end of expression");
					case ast::INVALID_EXPRESSION:
						io::printn("invalid expr");
					default:
						break;
				}
				
			}
			(void)a.print();
			io::printn();
		}
	};
	
}


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


fn Expr*? Parser.expr_head(&self)
{
	Token tk = self.advance()!;
	
	switch(tk.kind) {
		//& literal
		case INTEGER:
		case FLOAT:
			nextcase;
		//& identifier
		case IDENTIFIER:
			return mem::new(Expr, {
				.kind = ExprKind.PRIMARY,
				.primary = {
					.value = tk
				}
			});	
		//& "(" , expression , ")"
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

fn bool TokenKind.is_terminator(self) => self == TokenKind.SEMICOLON || self == TokenKind.NEW_LINE;


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
