module cyqra::parser::op;

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
