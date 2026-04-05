module cyqra::parser::op;
import std::collections::enummap;
import std::collections::maybe;

import cyqra::lexer::token;

alias _Operator_ = Maybe{ Operator };
alias Precedence = uint;

enum Typefix
{
	PREFIX,
	POSTFIX,
	INFIX
}
enum Associativity
{
	LEFT, RIGHT
}

struct Operator
{
    Precedence prec;
    // Typefix of;
    Associativity as;
}

struct OperatorDef
{	
	EnumMap{ TokenKind, _Operator_ } prefix_ops;
	EnumMap{ TokenKind, _Operator_ } postfix_ops;
	EnumMap{ TokenKind, _Operator_ } infix_ops;
}

fn OperatorDef new() {
	
	EnumMap{ TokenKind, _Operator_ } prefix_ops;
	prefix_ops.init(maybe::EMPTY);
	EnumMap{ TokenKind, _Operator_ } postfix_ops;
	postfix_ops.init(maybe::EMPTY);
	EnumMap{ TokenKind, _Operator_ } infix_ops;
	infix_ops.init(maybe::EMPTY);

	postfix_ops[OPEN_PHARANTESIS] = maybe::value({15, LEFT});
	postfix_ops[OPEN_BRACKET] = maybe::value({15, LEFT});
	postfix_ops[DOT] = maybe::value({15, LEFT});
	postfix_ops[PLUS_PLUS] = maybe::value({15, LEFT});
	postfix_ops[MINUS_MINUS] = maybe::value({15, LEFT});
	postfix_ops[EXCLAMATION] = maybe::value({16, LEFT});

	prefix_ops[PLUS] = maybe::value({14, RIGHT});
	prefix_ops[MINUS] = maybe::value({14, RIGHT});
	prefix_ops[PLUS_PLUS] = maybe::value({14, RIGHT});
	prefix_ops[MINUS_MINUS] = maybe::value({14, RIGHT});
	prefix_ops[EXCLAMATION] = maybe::value({14, RIGHT});


	infix_ops[STAR_STAR] = maybe::value({13, LEFT});
	infix_ops[STAR] = maybe::value({12, LEFT});
	infix_ops[SLASH] = maybe::value({12, LEFT});
	infix_ops[PERCENT] = maybe::value({12, LEFT});
	infix_ops[PLUS] = maybe::value({11, LEFT});
	infix_ops[MINUS] = maybe::value({11, LEFT});

	return {
		.prefix_ops = prefix_ops,
		.postfix_ops = postfix_ops,
		.infix_ops = infix_ops	
	};
}

fn Precedence? OperatorDef.check_prefix_op(&self, TokenKind tk)
{
	_Operator_ maybe_op = self.prefix_ops[tk];
	if (!maybe_op.has_value) return NOT_FOUND~;
	Operator op = maybe_op.value;
	return op.prec;
}

fn Precedence? OperatorDef.check_postfix_op(&self, TokenKind tk)
{
	_Operator_ maybe_op = self.postfix_ops[tk];
	if (!maybe_op.has_value) return NOT_FOUND~;
	Operator op = maybe_op.value;
	return op.prec;
}

fn Precedence? OperatorDef.check_infix_op(&self, TokenKind tk, Precedence prec)
{
	_Operator_ maybe_op = self.infix_ops[tk];
	if (!maybe_op.has_value) return NOT_FOUND~;
	
	Operator op = maybe_op.value;
	bool is_higher = op.prec > prec;
	bool is_right = op.as == Associativity.RIGHT;
	bool is_equal = op.prec == prec;

	if (is_higher || (is_right && is_equal)) {
		return op.prec;	
	}
	
	return NOT_FOUND~;
}
