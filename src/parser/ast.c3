module cyqra::parser::ast;
import cyqra::lexer;
import std::io;
import std::collections::list;

faultdef INVALID_EXPRESSION;

enum ExprKind
{
	PRIMARY,
	PREFIX,
	POSTFIX,
	INFIX,
	CALL,
	INDEX
}


struct Primary
{
	Token value;
}
struct Prefix
{
	TokenKind op;
	Expr* rhs;	
}
struct Postfix
{
	Expr* lhs;
	TokenKind op;
}
struct Infix
{
	Expr* lhs;
	TokenKind op;
	Expr* rhs;
}
struct Call
{
	Expr* callee;
	List{ Expr* } args;
}
struct Index
{
	Expr* object;
	Expr* index;
}


struct Expr
{
	ExprKind kind;
	union {
		Primary primary;
		Prefix prefix;
		Postfix postfix;
		Infix infix;
		Call call;
		Index index;
	}
}

fn void Expr.print(&self)
{
	io::print(self.kind);
	switch(self.kind)
	{
		case PRIMARY:
			io::print(self.primary.value);
			break;
		case PREFIX:
			io::print(self.prefix.op);
			io::print(" (");
			self.prefix.rhs.print();
			io::print(") ");
			break;
		case POSTFIX:
			io::print(" (");
			self.postfix.lhs.print();
			io::print(") ");
			io::print(self.postfix.op);
			break;
		case INFIX:
			io::print(" (");
			self.infix.lhs.print();
			io::print(") ");
			io::print(self.infix.op);
			io::print(" (");
			self.infix.rhs.print();
			io::print(") ");
			break;
		case CALL:
			io::print(" (");
			self.call.callee.print();
			io::print(" ARGS: ");
			foreach(arg : self.call.args) {
				arg.print();
			}
			io::print(") ");
		case INDEX:
			io::print(" (");
			self.index.object.print();
			self.index.index.print();
			io::print(") ");
	}
}
