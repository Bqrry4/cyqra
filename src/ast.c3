module cyqra::ast;
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
	//! TODO: free the tree
}

module cyqra::ast::expr;

import cyqra::lexer;
import cyqra::lexer::span;
import utils::nullable;
import cyqra::parser::op;

import std::io;
import std::collections::list;
import cyqra::sema::symbol_pool;
import cyqra::sema::types;

enum ExprKind {
	IDENTIFIER,
	LITERAL,
	VARIABLE,
	EXTERNAL,
	PREFIX,
	POSTFIX,
	INFIX,
	FUNCTION,
	CALL,
	INDEX,
	FIELD,
	BINDING,
	BLOCK,
	RETURN,
	PIPELINE,
	COLLECT,
	UNRESOLVED_IDENT,
	IN
}

union ExprDefs {
	Identifier ident;
	Literal literal;
	Variable variable;
	External external;
	Prefix prefix;
	Postfix postfix;
	Infix infix;
	Call call;
	Index index;
	Field field;
	Binding binding;
	Block block;
	Function fun;
	Return ret;
	Pipeline pipeline;
	Collect collect;

	Unresolved_Ident u_ident;
}

union Identifier {
	String name;
	SymbolID id;
}
struct Unresolved_Ident {
	Identifier ident;
	Token[] trailing;	
}

/* --- */
struct Literal {
	Type type;
	union {
		long _int;
		double _float;
		bool _bool;
	
		List_ _list;
		Record _record;
		Lambda _lambda;
		String_ _string;
	}
}

struct List_ {
	List{ Expr* } elements;
}

struct RecordField {
	Expr* key;
	Expr* value;
}
struct Record {
	List{ RecordField } fields;
}

enum StringPartKind {
    TEXT,
    INTERP,
}
struct StringPart {
    StringPartKind kind;
    union {
		String text;
		Expr* interp;
    }
}
struct String_ {
	List{ StringPart } parts;
}

struct Lambda {
	List{ Identifier } params;
	Expr* body;
}

struct Variable {
	SymbolID id;
}
struct External {
	String name;
}

struct Prefix {
	Operator op;
	Expr* rhs;	
}
struct Postfix {
	Expr* lhs;
	Operator op;
}
struct Infix {
	Expr* lhs;
	Operator op;
	Expr* rhs;
}
struct Call {
	Expr* callee;
	List{ Expr* } args;
}
struct Index {
	Expr* object;
	Expr* index;
}
struct Field {
	Expr* object;
	String name;
}
struct Binding {
	// TokenKind kind; binding kind
	Identifier ident;
	Nullable{ Expr* } type;
    Expr* value;
}
struct Block {
	List{ Expr* } stmts;
}

struct Function {
	Identifier ident;
	List{ Identifier } params;
	Expr* body;
}
struct Return {
	Nullable { Expr* } value;
}

enum PipeMode {
    OUT,
    ERR,
	OUT_ERR,
}
struct PipelineLink {
	Expr* expr;
	PipeMode mode;
}
struct Pipeline {
	Expr* head;
	List{ PipelineLink } links; 
}
struct Collect
{
	SymbolID id;
	Expr* inner;
}

// struct Loop {}
// struct Match {}
/* --- */

struct Expr
{
	ExprKind kind;
	ExprDefs defs;

	Span span;
}

macro @new($Type, #body, Span span)
{
	Expr expr = {
		.span = span,
	};

	var $field = "";
	$foreach $member : $reflect(Expr.defs).members:
 		$if $member.type == $Type:	
			$field = $member.name;
		$endif
	$endforeach

	var $init = @sprintf("expr.kind = %s;", @str_upper($Type::name));
	$init +++= @sprintf("expr.defs.%s = #body;", $field);
	$expand($init);
	return mem::new(Expr, expr);
}

// fn void Expr.print(&self)
// {
// 	io::print(self.kind);
// 	io::print(" (");
// 	switch(self.kind) {
// 	case PREFIX:
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
// 			io::print(self.binding.id);
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
// 		// case STRING:
// 		// 	foreach(part : self.string.parts)
// 		// 	{
// 		// 		if(part.kind == TEXT) {
// 		// 			io::print(part.text);
// 		// 		}
// 		// 		else {
// 		// 			part.interp.print();
// 		// 		}
// 		// 	}
// 		default:
// 	}
// 	io::print(") ");
// }

