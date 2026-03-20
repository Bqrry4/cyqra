module cyqra::lexer::token;

enum TokenKind : int @public
{
     RAW,

     /* Operators */
     PLUS, MINUS,
     EXCLAMATION,
     PLUS_PLUS, MINUS_MINUS,
     STAR_STAR,
     STAR, SLASH, SLASH_SLASH, PERCENT,
     SHL, SHR,
     LT, LTE, GT, GTE,
     EQ, NEQ,
     L_AND, L_OR,
     PIPE, PIPE_ALL,
     DOT, DOTX2, DOTX3,

     ASGN,
     PLUS_ASGN, MINUS_ASGN,
     STAR_ASGN, SLASH_ASGN,
     
     /* Brackets */
     OPEN_PHARANTESIS, CLOSED_PHARANTESIS,
     OPEN_BRACE, CLOSED_BRACE,
     OPEN_BRACKET, CLOSED_BRACKET,

     /* literals */
     INTEGER, FLOAT,
     STRING,

     IDENTIFIER,

     SEMICOLON, COMMA,

     NEW_LINE, SPACE,

     /* keywords */
     LET, MUT, ENV,
     IF, ELSE, WHILE,
     FN,

     /* string */
     D_QUOTES, DOLLAR_SIGN,
     STRING_PART, ESCAPED_CHAR,
     INTERP_START, INTERP_END,
     INTERP_IDENT,        
     EOF,
}


struct Token
{
     TokenKind kind;
     String slice;        
}

