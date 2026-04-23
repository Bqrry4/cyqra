module cyqra::diagnostic;
import std::io;

import cyqra::lexer::span;
import cyqra::lexer::token;

struct Diagnostic (Printable)
{

	String src_name;
	String source;
	
	String msg;
	Span cause;
}


fn void Diagnostic.error(&self,
	Span cause,
	String msg
){
    *self = {
		...*self,
		.msg = msg,
		.cause = cause
    };
}

/*
^───^
 ᗦ↞︎◃︎╰── expected =
*/

/*
^───────^
 ﾐ⚈ ﻌ ⚈ﾐ╰── expected =
*/

const LINES_SHOWN = 2;

//! Might not be the best solution
const String LINES  = "─────────────────────────────────────────";

fn sz? Diagnostic.to_format(&self, Formatter* formatter) @dynamic
{
	Span chunk = span::backtrack(self.source, self.cause, LINES_SHOWN);
	io::printn(chunk.slice);
	io::printn(self.cause);
	usz n = 0;
	n += formatter.printf("   ╭─[\e[0m%s:%d:%d\e[0m]\n", self.src_name, self.cause.row, self.cause.column)!;
	n += formatter.printf(" \e[2m%d │ \e[35m%s\e[0m\n", self.cause.row, chunk.slice)!;
	n += formatter.printf("   · %*s\e[31m%.*s┬ \e[0m\n", self.cause.column - self.cause.slice.len - 1, "", self.cause.slice.len, LINES)!;
	n += formatter.printf("   · %*s\e[31m╰── %s \e[0m\n", self.cause.column - 1, "", self.msg)!;
	n += formatter.printf("   ╰────")!;
	return n;
}
