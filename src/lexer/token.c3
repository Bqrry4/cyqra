module cyqra::lexer::token;
import cyqra::lexer::span;

enum TokenKind : int @public
{
    /* Operators */
	PLUS, MINUS,
	EXCLAMATION,
	PLUS_PLUS, MINUS_MINUS,
    STAR, STAR_STAR,
    SLASH, SLASH_SLASH, PERCENT,
	SHL, SHR,
	LT, LTE, GT, GTE,
	EQ, NEQ,
	AND, OR,
	AMPERSAND,
    PIPE, PIPE_ALL,
    DOT, DOTX2, DOTX3,

    ASGN,
    PLUS_ASGN, MINUS_ASGN,
    STAR_ASGN, SLASH_ASGN,
     
    /* Brackets */
    OPEN_PARENTHESIS, CLOSED_PARENTHESIS,
    OPEN_BRACE, CLOSED_BRACE,
    OPEN_BRACKET, CLOSED_BRACKET,

    /* literals */
    INTEGER, FLOAT,

    IDENTIFIER,
    SEMICOLON, COMMA,
    NEW_LINE, SPACE,

    /* keywords */
    LET, MUT, ENV,
    IF, ELSE, WHILE,
    FN, RETURN,

    /* string */
    D_QUOTES, DOLLAR_SIGN,
    STRING_PART, ESCAPED_CHAR,
    INTERP_START, INTERP_END,
    INTERP_IDENT,
             
    /* special */
    EOF,
    RAW,
}
 
struct Token
{
	TokenKind kind;
	Span span;
}

