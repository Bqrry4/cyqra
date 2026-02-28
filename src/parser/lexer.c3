module cyqra::lexer @private;
import std::collections::list;
import std::io;
import std::ascii;

enum TokenKind : int @public
{
     UNKNOWN,

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
     DOT, DOT_DOT,

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
     
     EOF,
}


struct Token @public
{
     TokenKind kind;
     // A slice over the big string
     String value;        
}


struct Lexer
{
     String source;
     List{ Token } output;

     char* tk_start;
     char* tk_current;
}
Lexer lexer;

fn List{ Token } lex(String source, List{ Token } tokens) @public
{
     lexer = {
          .source = source,
          .tk_current = source,
          .output = tokens
     };
     analyze();

     return lexer.output;
}


fn void analyze()
{
     Token tk;
     while((tk = next_token()).kind != TokenKind.EOF)
     {
         lexer.output.push(tk);
     }
}


// fn bool eol() => lexer.pos >= lexer.source.len;
<* Returns the character currently pointed by the @tk_current, then inc it *>
fn char advance() => *(lexer.tk_current++);
<* Checks the next *>
fn char peek() => *(lexer.tk_current);
<* *>
fn bool follows(char expect) => (peek() == expect) && lexer.tk_current++;

fn Token mk_token(TokenKind kind)
{
     return {
          .kind = kind,
          .value = (String)lexer.tk_start[
               ..lexer.tk_current - lexer.tk_start - 1
          ]
     };   
}


fn Token next_token()
{
     lexer.tk_start = lexer.tk_current;
     char c = advance();
      
     switch(c)
     {
          case '+': return follows('+') ? mk_token(TokenKind.PLUS_PLUS)
                         : follows('=') ? mk_token(TokenKind.PLUS_ASGN)
                                             : mk_token(TokenKind.PLUS);
          case '-': return follows('-') ? mk_token(TokenKind.MINUS_MINUS)
                         : follows('=') ? mk_token(TokenKind.MINUS_ASGN)
                                             : mk_token(TokenKind.MINUS);
          case '*': return follows('*') ? mk_token(TokenKind.STAR_STAR)
                         : follows('=') ? mk_token(TokenKind.STAR_ASGN)
                                             : mk_token(TokenKind.STAR);
          case '/': return follows('=') ? mk_token(TokenKind.SLASH_ASGN)
                                             : mk_token(TokenKind.SLASH);
          case '%': return mk_token(TokenKind.PERCENT);
          case '|': return follows('@') ? mk_token(TokenKind.PIPE_ALL)
                                             : mk_token(TokenKind.PIPE);
          case '<': return follows('=') ? mk_token(TokenKind.LTE)
                                             : mk_token(TokenKind.LT);
          case '>': return follows('=') ? mk_token(TokenKind.GTE)
                                             : mk_token(TokenKind.GT);
          case '=': return follows('=') ? mk_token(TokenKind.ASGN)
                                             : mk_token(TokenKind.EQ);
          case '!': return follows('=') ? mk_token(TokenKind.NEQ)
                                             : mk_token(TokenKind.EXCLAMATION);
          case '(': return mk_token(TokenKind.OPEN_PHARANTESIS);
          case ')': return mk_token(TokenKind.CLOSED_PHARANTESIS);
          case '[': return mk_token(TokenKind.OPEN_BRACKET);
          case ']': return mk_token(TokenKind.CLOSED_BRACKET);
          case '{': return mk_token(TokenKind.OPEN_BRACE);
          case '}': return mk_token(TokenKind.CLOSED_BRACE);
          case ';': return mk_token(TokenKind.SEMICOLON);
          case ',': return mk_token(TokenKind.COMMA);
          case '\0': return mk_token(TokenKind.EOF);
          case '"': return lex_string(c);
          default: return lex_unit(c); 
          
     }
 }

fn Token lex_unit(char c)
{
     switch {
          case ascii::is_space_m(c): return lex_space(c);
          case ascii::is_digit_m(c): return lex_number();
          case is_identifier_char(c): return lex_identifier();
          default: return mk_token(TokenKind.EOF);
      }
}

fn Token lex_space(char c)
{
     while (true)
     {
          switch (c) {
               case '\n': return mk_token(TokenKind.NEW_LINE);
               case ' ' : return mk_token(TokenKind.SPACE);     
               default: return mk_token(TokenKind.UNKNOWN);
          }
     }
}

fn Token lex_number()
{
     TokenKind kind = TokenKind.INTEGER;

     while (ascii::is_digit_m(peek())) advance();

     if (peek() == '.') {
        kind = TokenKind.FLOAT;
        advance();
        while (ascii::is_digit_m(peek())) advance();
     }
          
     return mk_token(kind);
}

fn Token lex_string(char c)
{
     

     return mk_token(TokenKind.EOF);
}

fn bool is_identifier_char(char c)
{
     return ascii::is_alnum_m(c) || c == '_';
}

fn Token lex_identifier()
{
     while(is_identifier_char(peek())) advance();

     return mk_token(TokenKind.IDENTIFIER);
}
