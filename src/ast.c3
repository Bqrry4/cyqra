module cyqra::ast;
import std::collections::list;

alias FnDecl = List{ Function* };
faultdef INVALID_EXPRESSION;

struct Ast
{
	List{ Expr* } expressions;	
}

fn Ast new()
{
	List{ Expr* } expressions;
	expressions.init(mem);
	return {
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

enum ExprKind: int(String field) {
	LITERAL {"literal"},
	VARIABLE {"variable"},
	EXTERNAL {"external"},
	PREFIX {"prefix"},
	POSTFIX {"postfix"},
	INFIX {"infix"},
	FUNCTION {"fun"},
	CALL {"call"},
	INDEX {"idx"},
	FIELD {"field"},
	BINDING {"bnd"},
	// BLOCK ,
	RETURN {"ret"},
	PIPELINE {"ppln"},
	// COLLECT,
	SEQUENCE {"seq"},
	FLAT_SEQUENCE {"fseq"},
	AMBIGUOUS_IDENT {"amb_ident"},
	IN {"in"},
	OPERATOR {"op"},
	IDENTIFIER {"ident"},
}

union ExprDefs {	
	Literal literal;
	Operator op;
	Identifier ident;
	AmbiguousIdent amb_ident;
	Sequence seq;
	FlatSequence fseq;
	Call call;
	Index idx;
	Field field;
	Binding bnd;
	Function fun;
	Return ret;
	Pipeline ppln;
	InKw in;
	
	Variable variable;
	External external;
	Prefix prefix;
	Postfix postfix;
	Infix infix;
	Collect collect;
}

typedef InKw = bool;

<*
	Pre-sema: name is live.
	Post-sema: id is live, points to a valid SymbolPool entry.
*>
union Identifier {
	String name;
	SymbolID id;
}
<*
	An ident followed by a space,
	that could possible be a shell call
*>
struct AmbiguousIdent {
	inline Identifier ident;
	Token[] trailing;	
}

/* --- */
struct Literal {
	Type type;
	union {
		long _int;
		double _float;
		bool _bool;
	
		LiteralList _list;
		LiteralRecord _record;
		LiteralLambda _lambda;
		LiteralString _string;
	}
}

struct RecordField {
	<* Always a String literal *>
	Expr* key;
	Expr* value;
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
alias LiteralRecord = List{ RecordField };
alias LiteralList = List { Expr* };

enum StrKind { STATIC, DYNAMIC }

struct LiteralString {
	StrKind kind;
	union {
		String static_str;
		List{ StringPart } dyn_str;
	}
}

struct LiteralLambda {
	List{ TypedIdent } params;
	Expr* body;
}
/* --- */

<* Sequence of expressions *>
alias Sequence = List{ Expr* };
<* Sequence of flatenned, leaf nodes that needs folding *>
alias FlatSequence = Sequence;


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
	inline TypedIdent typed_name;
    Expr* value;
}

struct TypedIdent {
	Identifier ident;
	Nullable{ Expr* } type;
}

struct Function {
	inline TypedIdent typed_name;
	List{ TypedIdent } params;
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
	List{ PipelineLink } links; 
	Expr* tail;
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
	inline ExprDefs defs;
	ExprKind kind;
	Span span;
}

macro @new(ExprKind $kind, #body, Span span)
{
	Expr expr = {
		.kind = $kind,
		.span = span,
	};

	var $init = @sprintf("expr.defs.%s = #body;", $kind.field);
	$expand($init);
	return mem::new(Expr, expr);
}
macro free(Expr* expr)
{
	mem::free(expr);
}
