module cyqra::parser::cursor;
import std::collections::list;
import std::io;

import cyqra::lexer::token;

enum CursorMode
{
	// skip white spaces
	NORMAL,
	// skip white spaces, keep ''\n'
	KEEP_LF,
	// skip nothing
	RAW,
}

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
	tk.span.slice = (String)(slice.ptr + slice.len - 1)[:0];
	return tk;
}

fn Token Cursor.advance(&self)
{
	self.skip_spaces(keep_lf: false);		
	if (self.eot()) return self.sentinel_token();
	return (self.tokens[self.current++]);
}
macro Token Cursor.peek(&self, CursorMode mode = NORMAL)
{
	if (mode != RAW) self.skip_spaces(mode == KEEP_LF);
	if(self.eot()) return self.sentinel_token();
	return (self.tokens[self.current]);
}
fn bool Cursor.eot(&self) => self.current >= self.tokens.len(); 

<*
	Consumes the token on match
*>
macro bool Cursor.follows(&self,
	TokenKind $expect, CursorMode $mode = NORMAL
){
	$switch $expect:
		$case SPACE:
			$mode = CursorMode.RAW;
		$case NEW_LINE:
			$mode = CursorMode.KEEP_LF;
	$endswitch

	Token tk = self.peek($mode);
	bool matches = tk.kind == $expect;
	matches && ++self.current;
	return matches;
}
fn bool Cursor.match(&self,
	TokenKind expect, CursorMode mode = NORMAL
) =>  self.peek(mode).kind == expect;

fn void Cursor.skip_spaces(&self, bool keep_lf = false)
{
	while (
		!self.eot() &&
		(
			(self.tokens[self.current].kind == TokenKind.SPACE) ||
			(!keep_lf && (self.tokens[self.current].kind == TokenKind.NEW_LINE))
		)
	) {
		self.current++;
	};
}
