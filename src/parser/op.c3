module cyqra::parser::op;
import std::collections::enummap;
import std::collections::maybe;
import std::collections::pair;

import cyqra::lexer::token;

faultdef NOT_ALLOWED;

alias Precedence = uint;
enum Associativity
{
	NONE,
	LEFT, RIGHT
}

enum Fixity {
	NONE,
	PREFIX,
	POSTFIX,
	INFIX
}

enum Operator: (Fixity fx, Precedence prec, Associativity as)
{
    INVALID { NONE, 0, NONE },

    POS {PREFIX, 15, RIGHT},
	NEG {PREFIX, 15, RIGHT},
	NOT {PREFIX, 15, RIGHT},
	ANY_CALL {PREFIX, 15, RIGHT},
	
	EXEC_ASYNC {POSTFIX, 3, LEFT},

    ADD {INFIX, 11, LEFT},
	SUB {INFIX, 11, LEFT},
	MUL {INFIX, 12, LEFT},
	DIV {INFIX, 12, LEFT},
	MOD	{INFIX, 12, LEFT},
	FLOOR_DIV {INFIX, 12, LEFT},
	POW {INFIX, 13, RIGHT},
	EQ  {INFIX, 5, LEFT},
	NEQ {INFIX, 5, LEFT},
	LT  {INFIX, 5, LEFT},
	GT  {INFIX, 5, LEFT},
	LTE {INFIX, 5, LEFT},
	GTE {INFIX, 5, LEFT},
	ASGN     {INFIX, 1, RIGHT},
	ADD_ASGN {INFIX, 1, RIGHT},
	SUB_ASGN {INFIX, 1, RIGHT},
	MUL_ASGN {INFIX, 1, RIGHT},
	DIV_ASGN {INFIX, 1, RIGHT},

	PIPE     {INFIX, 2, LEFT},
	PIPE_ERR {INFIX, 2, LEFT},
	PIPE_ALL {INFIX, 2, LEFT},
}

fn Operator to_prefix(TokenKind tk)
{
	switch (tk) {
	case PLUS: return POS;
	case MINUS: return NEG;
	case EXCLAMATION: return NOT;
	case ASPERAND: return ANY_CALL;
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
