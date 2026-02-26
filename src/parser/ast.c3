module cyqra::parser::ast;
import cyqra::lexer;
import std::io;

faultdef INVALID_EXPRESSION;

enum ExprKind
{
	PRIMARY,
	PREFIX,
	POSTFIX,
	INFIX	
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


struct Expr
{
	ExprKind kind;
	union {
		Primary primary;
		Prefix prefix;
		Postfix postfix;
		Infix infix;
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
	}
}
