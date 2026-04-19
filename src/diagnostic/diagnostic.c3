module cyqra::diagnostic;
import std::io;

struct Diagnostic (Printable)
{

	String src_name;
	String msg;
	
	uint line;
	uint column;
	uint length;
	String span;
}

//! Might not be the best solution
const String LINES  = "─────────────────────────────────────────";

fn sz? Diagnostic.to_format(&self, Formatter* formatter) @dynamic
{
	
	usz n = 0;
	n += formatter.printf("   ╭─[\e[0m%s:%d:%d\e[0m]\n", self.src_name, self.line, self.column)!;
	n += formatter.printf(" \e[2m%d │ \e[35m%s\e[0m\n", self.line, self.span)!;
	n += formatter.printf("   · %*s\e[31m%.*s┬ \e[0m\n", self.column - self.length - 1, "", self.length, LINES)!;
	n += formatter.printf("   · %*s\e[31m╰── %s \e[0m\n", self.column - 1, "", self.msg)!;
	n += formatter.printf("   ╰────")!;
	return n;
}
