module cyqra::lexer;
import std::collections::list;
import std::io;
import std::ascii;
import libc;

struct Lexer
{
     Allocator allocator;

     String source;
     List{ Token } output;

     char* tk_start;
     char* tk_current;
 }

fn Lexer new(Allocator allocator, String source) @public
{
     
     List{ Token } tokens;
     tokens.init(allocator);
     return {
          .allocator = allocator,
          .source = source,
          .output = tokens,
          .tk_start = source,
          .tk_current = source
     };
}


fn List{ Token } Lexer.analyze(&self)
{
     Token tk;
     while((tk = self.next_token()).kind != TokenKind.EOF)
     {
         self.output.push(tk);
     }
     return self.output;
}


// fn bool eol() => lexer.pos >= lexer.source.len;
<* Returns the character currently pointed by the @tk_current, then inc it *>
fn char Lexer.advance(&self) => *(self.tk_current++);
<* Checks the next *>
fn char Lexer.peek(&self) => *(self.tk_current);
<* *>
fn bool Lexer.follows(&self, char expect) => (self.peek() == expect) && self.tk_current++;

fn Token Lexer.mk_token(&self, TokenKind kind)
{
     return {
          .kind = kind,
          .value = (String)self.tk_start[
               ..self.tk_current - self.tk_start - 1
          ]
     };   
}


fn Token Lexer.next_token(&self)
{
     self.tk_start = self.tk_current;
     char c = self.advance();
      
     switch(c)
     {
          case '+': return self.follows('+') ? self.mk_token(TokenKind.PLUS_PLUS)
                         : self.follows('=') ? self.mk_token(TokenKind.PLUS_ASGN)
                                             : self.mk_token(TokenKind.PLUS);
          case '-': return self.follows('-') ? self.mk_token(TokenKind.MINUS_MINUS)
                         : self.follows('=') ? self.mk_token(TokenKind.MINUS_ASGN)
                                             : self.mk_token(TokenKind.MINUS);
          case '*': return self.follows('*') ? self.mk_token(TokenKind.STAR_STAR)
                         : self.follows('=') ? self.mk_token(TokenKind.STAR_ASGN)
                                             : self.mk_token(TokenKind.STAR);
          case '/': return self.follows('=') ? self.mk_token(TokenKind.SLASH_ASGN)
                                             : self.mk_token(TokenKind.SLASH);
          case '%': return self.mk_token(TokenKind.PERCENT);
          case '|': return self.follows('@') ? self.mk_token(TokenKind.PIPE_ALL)
                                             : self.mk_token(TokenKind.PIPE);
          case '<': return self.follows('=') ? self.mk_token(TokenKind.LTE)
                                             : self.mk_token(TokenKind.LT);
          case '>': return self.follows('=') ? self.mk_token(TokenKind.GTE)
                                             : self.mk_token(TokenKind.GT);
          case '=': return self.follows('=') ? self.mk_token(TokenKind.ASGN)
                                             : self.mk_token(TokenKind.EQ);
          case '!': return self.follows('=') ? self.mk_token(TokenKind.NEQ)
                                             : self.mk_token(TokenKind.EXCLAMATION);
          case '(': return self.mk_token(TokenKind.OPEN_PHARANTESIS);
          case ')': return self.mk_token(TokenKind.CLOSED_PHARANTESIS);
          case '[': return self.mk_token(TokenKind.OPEN_BRACKET);
          case ']': return self.mk_token(TokenKind.CLOSED_BRACKET);
          case '{': return self.mk_token(TokenKind.OPEN_BRACE);
          case '}': return self.mk_token(TokenKind.CLOSED_BRACE);
          case ';': return self.mk_token(TokenKind.SEMICOLON);
          case ',': return self.mk_token(TokenKind.COMMA);
          case '\0': return self.mk_token(TokenKind.EOF);
          case '"': return self.lex_string(c);
          default: return self.lex_unit(c); 
          
     }
 }

fn Token Lexer.lex_unit(&self, char c)
{
     switch {
          case ascii::is_space_m(c): return self.lex_space(c);
          case ascii::is_digit_m(c): return self.lex_number();
          case is_identifier_char(c): return self.lex_identifier();
          default: return self.mk_token(TokenKind.EOF);
      }
}

fn Token Lexer.lex_space(&self, char c)
{
     while (true)
     {
          switch (c) {
               case '\n': return self.mk_token(TokenKind.NEW_LINE);
               default: return self.mk_token(TokenKind.SPACE);
          }
     }
}

fn Token Lexer.lex_number(&self)
{
     TokenKind kind = TokenKind.INTEGER;

     while (ascii::is_digit_m(self.peek())) self.advance();

     if (self.peek() == '.') {
        kind = TokenKind.FLOAT;
        self.advance();
        while (ascii::is_digit_m(self.peek())) self.advance();
     }
          
     return self.mk_token(kind);
}

fn Token Lexer.lex_string(&self, char c)
{
     

     return self.mk_token(TokenKind.EOF);
}

fn bool is_identifier_char(char c)
{
     return ascii::is_alnum_m(c) || c == '_';
}

fn Token Lexer.lex_identifier(&self)
{
     while(is_identifier_char(self.peek())) self.advance();

     if(try keyword = self.check_keywords()) {
          return keyword;
     }
     
     return self.mk_token(TokenKind.IDENTIFIER);
}

fn Token? Lexer.check_keywords(&self)
{
     switch {
          case !libc::memcmp(self.tk_start, "let", 3): return self.mk_token(TokenKind.LET);
          case !libc::memcmp(self.tk_start, "mut", 3): return self.mk_token(TokenKind.MUT);
          case !libc::memcmp(self.tk_start, "env", 3): return self.mk_token(TokenKind.ENV);
          case !libc::memcmp(self.tk_start, "alias", 5): return self.mk_token(TokenKind.ALIAS);
          case !libc::memcmp(self.tk_start, "fn", 2): return self.mk_token(TokenKind.FN);
          case !libc::memcmp(self.tk_start, "if", 2): return self.mk_token(TokenKind.IF);
          case !libc::memcmp(self.tk_start, "else", 2): return self.mk_token(TokenKind.ELSE);
          case !libc::memcmp(self.tk_start, "while", 5): return self.mk_token(TokenKind.WHILE);
     }
      
     return NOT_FOUND~;
}
