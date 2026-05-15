module cyqra::lexer::token;
import cyqra::lexer::span;

enum TokenKind : int @public
{
    /* Operators */
	PLUS, MINUS,
	EXCLAMATION,
    STAR, STARX2,
    SLASH, SLASHX2, PERCENT,
	LT, LTE, GT, GTE,
	EQ, NEQ, EQX2,
	PLUS_EQ, MINUS_EQ,
    STAR_EQ, SLASH_EQ,
	AMP, AMPX2,
	PIPE, EXCL_PIPE,
	PIPE_AMP, PIPEX2,
	DOT, DOTX2, DOTX3,

         
    /* Brackets */
    OPEN_PARENTHESIS, CLOSED_PARENTHESIS,
    OPEN_BRACE, CLOSED_BRACE,
    OPEN_BRACKET, CLOSED_BRACKET,

    /* literals */
    INTEGER, FLOAT,

    IDENTIFIER,
    COLON, SEMICOLON, COMMA,
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

