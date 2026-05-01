module cyqra::parser::op;
import std::collections::enummap;
import std::collections::maybe;
import std::collections::pair;

import cyqra::lexer::token;

faultdef NOT_ALLOWED;

alias Precedence = uint;
enum Associativity
{
	LEFT, RIGHT
}

enum Operator
{
    INVALID,
    ADD, SUB,
	MUL, DIV, MOD,
	FLOOR_DIV, POW,
    DOT_ACCESS,
    NOT,
	EXEC_ASYNC
}

struct OperatorDef
{
	Operator op;
	Precedence prec;
}

/* Doesn't make sense to have it variate */
const PREFIX_PREC = 15;
const Operator[] PREFIX = {
	[TokenKind.PLUS] = ADD,
	[TokenKind.MINUS] = SUB,
	[TokenKind.EXCLAMATION] = NOT,
};
const OperatorDef[] POSTFIX = {
	[TokenKind.AMPERSAND] = { EXEC_ASYNC, 0 },
	
};
const Pair{ OperatorDef, Associativity }[] INFIX = {
	[TokenKind.STAR_STAR] = {{ POW, 13 }, LEFT},
	[TokenKind.STAR] = {{ MUL, 12 }, LEFT},
	[TokenKind.SLASH] = {{ DIV, 12 }, LEFT},
	[TokenKind.PERCENT] = {{ MOD, 12}, LEFT},
	[TokenKind.PLUS] = {{ADD, 11}, LEFT},
	[TokenKind.MINUS] = {{SUB, 11}, LEFT},
};

fn Operator? check_prefix(TokenKind tk)
{
	if (tk.ordinal >= PREFIX.len) return NOT_ALLOWED~;
	Operator op = PREFIX[tk];
	if (op == INVALID) return NOT_ALLOWED~;
	return op;
}

fn OperatorDef? check_postfix(TokenKind tk, Precedence prec)
{
	if (tk.ordinal >= POSTFIX.len) return NOT_ALLOWED~;
	OperatorDef op_def = POSTFIX[tk];
	if (op_def.op == INVALID) return NOT_ALLOWED~;
	if (op_def.prec <= prec) return NOT_ALLOWED~;
	return op_def;
}

fn OperatorDef? check_infix(TokenKind tk, Precedence prec)
{
	if (tk.ordinal >= INFIX.len) return NOT_ALLOWED~;
	OperatorDef op_def = INFIX[tk].first;
	Associativity as = INFIX[tk].second;
	if (op_def.op != INVALID) return NOT_ALLOWED~;
	
	bool is_higher = op_def.prec > prec;
	bool is_right = as == Associativity.RIGHT;
	bool is_equal = op_def.prec == prec;

	if (is_higher || (is_right && is_equal)) {
		return op_def;	
	}
	
	return NOT_ALLOWED~;
}
