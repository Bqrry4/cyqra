module cyqra::parser::cursor;
import std::collections::list;
import std::io;

import cyqra::lexer::token;

faultdef OUT_OF_TOKENS;

struct Cursor
{
	List{ Token } tokens;

	uint start;
	uint current;
}

fn void Cursor.reset(&self)
{
	self.start = 0;
	self.current = 0;
}
fn Token? Cursor.advance(&self, bool skip_lf = true)
{
	self.skip_spaces(skip_lf);		
	if (self.eot()) return OUT_OF_TOKENS~;
	return (self.tokens[self.current++]);
}
fn Token? Cursor.peek(&self, bool skip_wp = true, bool skip_lf = true)
{
	if (skip_wp) self.skip_spaces(skip_lf);
	if(self.eot()) return OUT_OF_TOKENS~;
	return (self.tokens[self.current]);
}
fn bool Cursor.eot(&self) => self.current >= self.tokens.len(); 

<*
	@consume "To consume the token on match"
*>
fn bool Cursor.follows(&self, TokenKind expect, bool consume = true, bool skip_wp = true, bool skip_lf = true)
{
	Token? tk = self.peek(skip_wp, skip_lf);
	bool matches = @ok(tk) && (tk!!.kind == expect);
	matches && consume && ++self.current;
	return matches;
} 

fn void Cursor.skip_spaces(&self, bool skip_lf = true)
{
	while (
		!self.eot() &&
		(
			(self.tokens[self.current].kind == TokenKind.SPACE) ||
			(skip_lf && (self.tokens[self.current].kind == TokenKind.NEW_LINE))
		)
	) {
		self.current++;
	};
}

fn String Cursor.expr_span(&self)
{
	String left = self.tokens[self.start].slice;
	String right = self.tokens[self.current - (usz)1].slice;
	return (String)left.ptr[..(right.ptr - left.ptr) + right.len];	
}
