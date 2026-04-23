module cyqra::parser::cursor;
import std::collections::list;
import std::io;

import cyqra::lexer::token;

struct Cursor
{
	List{ Token } tokens;
	usz current;
}

fn void Cursor.reset(&self)
{
	self.current = 0;
}

<*
	@return `Sentinel token, defined as:
		kind: EOF
		column: last.column + 1
		slice: empty slice positioned at the end of the source
			ptr: &source[len - 1]
			length: 0
	`
*>
fn Token Cursor.sentinel_token(&self)
{
	Token tk = self.tokens.last()!!;
	tk.kind = EOF;
	tk.span.column++;
	String slice = tk.span.slice;
	tk.span.slice = (String)(slice.ptr + slice.len)[:0];
	return tk;
}

fn Token Cursor.advance(&self, bool skip_lf = true)
{
	self.skip_spaces(skip_lf);		
	if (self.eot()) return self.sentinel_token();
	return (self.tokens[self.current++]);
}
fn Token Cursor.peek(&self, bool skip_wp = true, bool skip_lf = true)
{
	if (skip_wp) self.skip_spaces(skip_lf);
	if(self.eot()) return self.sentinel_token();
	return (self.tokens[self.current]);
}
fn bool Cursor.eot(&self) => self.current >= self.tokens.len(); 

<*
	@consume "To consume the token on match"
*>
fn bool Cursor.follows(&self, TokenKind expect, bool consume = true, bool skip_wp = true, bool skip_lf = true)
{
	Token tk = self.peek(skip_wp, skip_lf);
	bool matches = tk.kind == expect;
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
