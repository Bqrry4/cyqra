module cyqra::parser::ast;
import std::collections::list;

faultdef INVALID_EXPRESSION;

struct Ast
{
	Allocator allocator;
	List{ Expr* } expressions;	
}

fn Ast new(Allocator allocator)
{
	List{ Expr* } expressions;
	expressions.init(allocator);
	return {
		.allocator = allocator,
		.expressions = expressions
	};
}

fn void Ast.clear(&self)
{
	self.expressions.clear();
}

fn void Ast.free(&self)
{
	self.expressions.free();
}

module cyqra::parser::ast::expr;

import cyqra::lexer;
import cyqra::lexer::span;
import utils::nullable;
import cyqra::parser::op;

import std::io;
import std::collections::list;



enum ExprKind
{
	PRIMARY,
	STRINGLIT,
	PREFIX,
	POSTFIX,
	INFIX,
	CALL,
	INDEX,
	BINDING,
	BLOCK,
	FUNCTION,
	RETURN
}

struct Primary
{
	Token token;
}
struct Prefix
{
	Operator op;
	Expr* rhs;	
}
struct Postfix
{
	Expr* lhs;
	Operator op;
}
struct Infix
{
	Expr* lhs;
	Operator op;
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
struct Binding
{
	TokenKind type;
    Token identifier;
    Expr* value;
}
struct Block
{
	List{ Expr* } stmts;
}
struct Function
{
	Token identifier;
	List{ String } params;
	Expr* body;
}
struct Return
{
	Nullable { Expr* } value;
}

enum StringPartKind
{
    TEXT,
    INTERP,
}
struct StringPart
{
    StringPartKind kind;
    union {
        String text;
        Expr* interp;
    }
}

struct StringLit
{
	List{ StringPart } parts;
}

struct Expr
{
	struct {
		Primary primary;
		StringLit string; 
		Prefix prefix;
		Postfix postfix;
		Infix infix;
		Call call;
		Index index;
		Binding binding;
		Block block;
		Function fun;
		Return ret;
	}
	Span span;
	ExprKind kind;
}

macro @new($Type, #body, Span span)
{
	Expr expr = {
		.span = span,
	};

	var $field = "";
	$foreach $member : Expr::members[0].members:
 		$if $member.type == $Type:	
			$field = $member.name;
		$endif
	$endforeach

	var $init = @sprintf("expr.kind = %s;", @str_upper($Type::name));
	$init +++= @sprintf("expr.%s = #body;", $field);
	$expand($init);
	return mem::new(Expr, expr);
}

// fn void Expr.print(&self)
// {
// 	io::print(self.kind);
// 	io::print(" (");
// 	switch(self.kind)
// 	{
// 		case PRIMARY:
// 			io::print(self.primary.token);
// 			break;
// 		case PREFIX:
// 			io::print(self.prefix.op);
// 			io::print(" (");
// 			self.prefix.rhs.print();
// 			io::print(") ");
// 			break;
// 		case POSTFIX:
// 			io::print(" (");
// 			self.postfix.lhs.print();
// 			io::print(") ");
// 			io::print(self.postfix.op);
// 			break;
// 		case INFIX:
// 			io::print(" (");
// 			self.infix.lhs.print();
// 			io::print(") ");
// 			io::print(self.infix.op);
// 			io::print(" (");
// 			self.infix.rhs.print();
// 			io::print(") ");
// 			break;
// 		case CALL:
// 			self.call.callee.print();
// 			io::print(" ARGS: ");
// 			foreach(arg : self.call.args) {
// 				arg.print();
// 			}
// 		case INDEX:
// 			self.index.object.print();
// 			self.index.index.print();
// 		case BINDING:
// 			io::print(self.binding.type);
// 			io::print(self.binding.identifier);
// 			self.binding.value.print();
// 			break;
// 		case BLOCK:
// 			foreach(stmt : self.block.stmts)
// 			{
// 				stmt.print();
// 			}
// 		case FUNCTION:
// 			io::print(self.fun.identifier);
// 			io::print("PARAMS ");
// 			foreach(param : self.fun.params)
// 			{
// 				io::print(param);
// 			}
// 			self.fun.body.print();
// 			break;
// 		case STRING:
// 			foreach(part : self.string.parts)
// 			{
// 				if(part.kind == TEXT) {
// 					io::print(part.text);
// 				}
// 				else {
// 					part.interp.print();
// 				}
// 			}
// 		default:
// 	}
// 	io::print(") ");
// }

