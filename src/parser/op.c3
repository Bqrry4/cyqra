module cyqra::parser::op;
import std::collections::enummap;
import std::collections::maybe;
import std::collections::pair;

import cyqra::lexer::token;

faultdef NOT_ALLOWED;

alias Precedence = uint;
enum Associativity
{
	INVALID,
	LEFT, RIGHT
}

enum Operator: (Precedence prec, Associativity as)
{
    INVALID { 0, INVALID },
	//prefix
    POS {15, RIGHT},
	NEG {15, RIGHT},
	NOT {15, RIGHT},
	//postfix 
	EXEC_ASYNC {3, LEFT},

	//infix
    ADD {11, LEFT},
	SUB {11, LEFT},
	MUL {12, LEFT},
	DIV {12, LEFT},
	MOD	{12, LEFT},
	FLOOR_DIV {12, LEFT},
	POW {13, RIGHT},
	EQ  {5, LEFT},
	NEQ {5, LEFT},
	LT  {5, LEFT},
	GT  {5, LEFT},
	LTE {5, LEFT},
	GTE {5, LEFT},
	ASGN     {1, RIGHT},
	ADD_ASGN {1, RIGHT},
	SUB_ASGN {1, RIGHT},
	MUL_ASGN {1, RIGHT},
	DIV_ASGN {1, RIGHT},

	PIPE     {2, LEFT},
	PIPE_ERR {2, LEFT},
	PIPE_ALL {2, LEFT},
}

fn Operator to_prefix(TokenKind tk)
{
	switch (tk) {
	case PLUS: return POS;
	case MINUS: return NEG;
	case EXCLAMATION: return NOT;
	default: return INVALID;
	}
}

fn Operator to_postfix(TokenKind tk)
{
	switch (tk) {
	case AMP: return EXEC_ASYNC;
	default: return INVALID;
	}
}
fn Operator to_infix(TokenKind tk)
{
	switch (tk) {
	case STARX2: return POW;
	case STAR: return MUL;
	case SLASH: return DIV;
	case SLASHX2: return FLOOR_DIV;
	case PERCENT: return MOD;
	case PLUS: return ADD;
	case MINUS: return SUB;
	case EQX2: return EQ;
	case NEQ: return NEQ;
	case LT: return LT;
	case LTE: return LTE;
	case GT: return GTE;
	case EQ: return ASGN;
	case PLUS_EQ: return ADD_ASGN;
	case MINUS_EQ: return SUB_ASGN;
	case STAR_EQ: return MUL_ASGN;
	case SLASH_EQ: return DIV_ASGN;
	case PIPE: return PIPE;
	case EXCL_PIPE: return PIPE_ERR;
	case PIPE_AMP: return PIPE_ALL;
	default: return INVALID;
	}
}
