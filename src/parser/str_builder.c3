module cyqra::parser::str_builder;
import cyqra::ast::expr;
import cyqra::lexer::span;
import std::collections::list;
import std::io;

struct LiteralStringBuilder {
	String stc;
	List{ StringPart } dyn;
	Span pending;
}

fn void LiteralStringBuilder.push_text(&self, StringPart part)
{
	if (!self.dyn.len() && !self.stc.len) {
		self.stc = part.text;
		return;
	}
	push_dynamic(self, part);
}

fn void LiteralStringBuilder.push_interp(&self, StringPart part) => push_dynamic(self, part);

fn void push_dynamic(LiteralStringBuilder* self, StringPart part) @local
{
	//@ Promote it to dynamic
	if (!self.dyn.len()) {
		self.dyn.init(mem);
		if (self.stc.len) self.dyn.push({ .kind = TEXT, .text = self.stc });
	}
	self.dyn.push(part);
}

fn void LiteralStringBuilder.push(&self, StringPart part)
{
	if (!self.dyn.len() && part.kind == TEXT && !self.stc.len) {
		self.stc = part.text;
		return;
	}
	if (!self.dyn.len()) {
		self.dyn.init(mem);
		if (self.stc.len) self.dyn.push({ .kind = TEXT, .text = self.stc });
	}
	self.dyn.push(part);
}
<*
	Extending a string, when it is composed from multiple tokens. 
*>
fn void LiteralStringBuilder.extend(&self, Span span)
{
	self.pending = self.pending.slice.len ? self.pending.extend(span) : span;
}
fn void LiteralStringBuilder.flush(&self)
{
	if (!self.pending.slice.len) return;
	self.push_text({ .kind = TEXT, .text = self.pending.slice });
	self.pending = {};
}
fn LiteralString LiteralStringBuilder.finish(&self)
{
	self.flush();
	if (self.dyn.len()) return { .kind = DYNAMIC, .dyn = self.dyn };
	return { .kind = STATIC, .stc = self.stc };
}
