module cyqra::parser::cursor;
import std::collections::list;

import cyqra::lexer::token;
import cyqra::lexer::span;

enum CursorMode
{
	<* skip white spaces and terminators *>
	NORMAL,
	<* skip white spaces, keep '\n' and ';' *>
	KEEP_SEP,
	<* don't skip *>
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
	@return ```
		Sentinel token, defined as:
		kind: EOF
		span.column: last.column + 1
		span.slice: empty slice positioned at the end of the last token
			ptr: &last.span.slice[len]
			length: 0
	```
*>
fn Token Cursor.sentinel_token(&self)
{
	Token eot = self.tokens.last()!!;
	eot.kind = EOF;
	
	Span* span = &eot.span;
	span.column += span.slice.len;
	span.slice = (String)(span.slice.ptr + span.slice.len)[:0];

	return eot;
}

fn Token Cursor.advance(&self)
{
	self.skip(keep_sep: false);		
	if (self.eot()) return self.sentinel_token();
	return (self.tokens[self.current++]);
}
macro Token Cursor.peek(&self, CursorMode mode = NORMAL)
{
	if (mode != RAW) self.skip(mode == KEEP_SEP);
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
			$mode = CursorMode.KEEP_SEP;
	$endswitch

	Token tk = self.peek($mode);
	bool matches = tk.kind == $expect;
	matches && ++self.current;
	return matches;
}
fn bool Cursor.match(&self,
	TokenKind expect, CursorMode mode = NORMAL
) =>  self.peek(mode).kind == expect;

<*
	Skips new lines, spaces and semicolon
	@keep_sep "Will skip only spaces"
*>
fn void Cursor.skip(&self, bool keep_sep = false)
{
	while (!self.eot()) {
		TokenKind kind = self.tokens[self.current].kind;
		bool is_space = kind == SPACE;
		bool is_separator = kind == NEW_LINE
							|| kind == SEMICOLON;
		if (!is_space && (keep_sep || !is_separator)) {
			break;
		}
		self.current++;
	}
}
