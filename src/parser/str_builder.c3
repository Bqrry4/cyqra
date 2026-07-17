module cyqra::parser::str_builder;
import cyqra::ast::expr;
import cyqra::lexer::span;
import std::collections::list;
import std::io;

struct LiteralStringBuilder {
	String static_str;
	List{ StringPart } dyn_str;
	Span pending;
}

fn void LiteralStringBuilder.push_text(&self, StringPart part)
{
	if (!self.dyn_str.len() && !self.static_str.len) {
		self.static_str = part.text;
		return;
	}
	push_dynamic(self, part);
}

fn void LiteralStringBuilder.push_interp(&self, StringPart part) => push_dynamic(self, part);

fn void push_dynamic(LiteralStringBuilder* self, StringPart part) @local
{
	//@ Promote it to dynamic
	if (!self.dyn_str.len()) {
		self.dyn_str.init(mem);
		if (self.static_str.len) self.dyn_str.push({ .kind = TEXT, .text = self.static_str });
	}
	self.dyn_str.push(part);
}

fn void LiteralStringBuilder.push(&self, StringPart part)
{
	if (!self.dyn_str.len() && part.kind == TEXT && !self.static_str.len) {
		self.static_str = part.text;
		return;
	}
	if (!self.dyn_str.len()) {
		self.dyn_str.init(mem);
		if (self.static_str.len) self.dyn_str.push({ .kind = TEXT, .text = self.static_str });
	}
	self.dyn_str.push(part);
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
	if (self.dyn_str.len()) return { .kind = DYNAMIC, .dyn_str = self.dyn_str };
	return { .kind = STATIC, .static_str = self.static_str };
}
