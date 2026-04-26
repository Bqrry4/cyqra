module cyqra::lexer;
import std::collections::list;
import std::io;
import libc;

enum Mode
{
     DEFAULT,
     STRING,
     INTERPOLATION,
     RAW
}

struct LexContext
{
     Mode mode;
     union {
          struct interp { uint brace_depth; }
     }
}

struct Lexer
{
     Allocator allocator;

     String source;
     List{ Token } output;

     Cursor cursor;
     List{ LexContext } ctxs;
}

fn Lexer new(Allocator allocator) @public
{
     List{ Token } tokens;
     tokens.init(allocator);
     List{ LexContext } ctxs;
     ctxs.init(allocator);
     ctxs.push({
          .mode = DEFAULT
     });
     
     return {
          .allocator = allocator,
          .output = tokens,
          .ctxs = ctxs
     };
}

fn void Lexer.free(&self)
{
     self.output.free();
     self.ctxs.free();
}

fn void Lexer.reset(&self)
{
     self.output.clear();
     //@ Lexer could exit on non default mode.
     // As example on errors inside INTERPOLATION.
     // Or if in repl mode with valid expressions,
     // that don't have further input to return. 
     // such as `echo $test`
     self.ctxs.clear();
     self.ctxs.push({
          .mode = DEFAULT
     });

}

fn void Lexer.set_source(&self, String source)
{
     self.source = source;
     self.cursor = {
          .start = source,
          .current = source,
          .end = (char*)source + source.len
     };
}


fn void List{ LexContext }.switch_to(&self, Mode mode) => self.push({
     .mode = mode
});
fn void List{ LexContext }.switch_back(&self) => self.pop()!!;

fn LexContext* Lexer.ctx(&self) => &self.ctxs[self.ctxs.len() - 1];

fn List{ Token } Lexer.analyze(&self, String source)
{
     self.reset();
     self.set_source(source);
          
     while (!self.cursor.eof()) {
         if (catch self.next_token()) break;
     }
    
     return self.output;
}
 
fn void Lexer.emit(&self, TokenKind kind)
{
     self.output.push({
          .kind = kind,
          .span = self.cursor.captured_span()
     });

     self.cursor.sync_start();
}

fn void? Lexer.next_token(&self)
{
     char c = self.cursor.advance();
     switch (self.ctx().mode) {
          case DEFAULT:
          case INTERPOLATION:
               self.lex_code(c)!;  
          case STRING:
          case RAW:
               self.lex_text(c)!;
     }
 }

fn void? Lexer.lex_code(&self, char c)
{
     switch(c) {
          case '+': self.cursor.follows('+') ? self.emit(PLUS_PLUS)
                    : self.cursor.follows('=') ? self.emit(PLUS_ASGN)
                                             : self.emit(PLUS);
          case '-': self.cursor.follows('-') ? self.emit(MINUS_MINUS)
                    : self.cursor.follows('=') ? self.emit(MINUS_ASGN)
                                        : self.emit(MINUS);
          case '*': self.cursor.follows('*') ? self.emit(STAR_STAR)
                    : self.cursor.follows('=') ? self.emit(STAR_ASGN)
                                        : self.emit(STAR);
          case '/': self.cursor.follows('=') ? self.emit(SLASH_ASGN)
                                      : self.emit(SLASH);
          case '%': self.emit(PERCENT);
          case '|': self.cursor.follows('@') ? self.emit(PIPE_ALL)
                                      : self.emit(PIPE);
          case '<': self.cursor.follows('=') ? self.emit(LTE)
                                      : self.emit(LT);
          case '>': self.cursor.follows('=') ? self.emit(GTE)
                                      : self.emit(GT);
          case '=': self.cursor.follows('=') ? self.emit(ASGN)
                                      : self.emit(EQ);
          case '!': self.cursor.follows('=') ? self.emit(NEQ)
                                      : self.emit(EXCLAMATION);
          case '(': self.emit(OPEN_PHARANTESIS);
          case ')': self.emit(CLOSED_PHARANTESIS);
          case '[': self.emit(OPEN_BRACKET);
          case ']': self.emit(CLOSED_BRACKET);
          case '{': {
               if (self.ctx().mode != INTERPOLATION) {
                       self.emit(OPEN_BRACE);
               }

               self.ctx().interp.brace_depth++;                  
          }
          case '}': {
               if (self.ctx().mode != INTERPOLATION) {
                    self.emit(CLOSED_BRACE);
                    break;
               }

               if (self.ctx().interp.brace_depth == 0) {
                    self.emit(INTERP_END);
                    self.ctxs.switch_back();
                    break;
               }

               self.ctx().interp.brace_depth--;
          }
          case ';': self.emit(SEMICOLON);
          case ',': self.emit(COMMA);
          case '.': self.cursor.follows('.') ?
                    (self.cursor.follows('.') ? self.emit(DOTX3) : self.emit(DOTX2))
                    : self.emit(DOT);
          case '\0': self.emit(EOF);
          case '"': {
               self.ctxs.switch_to(STRING);              
               self.emit(D_QUOTES);
          }
          case '#': self.lex_comment();                    
          default: switch {
               case ascii::is_space(c): self.lex_space(c);
               case ascii::is_digit(c): self.lex_number();
               case is_identifier_char(c): self.lex_identifier();
               default: {
                    self.ctxs.switch_to(RAW);
                    self.lex_text(c)!;
               }
          }
     }
}

fn void? Lexer.lex_text(&self, char c)
{
     switch (c) {
          case '"': {
               if (self.ctx().mode == STRING) {
                    self.ctxs.switch_back();
                    self.emit(D_QUOTES);
                    break;
               }
               self.ctxs.switch_to(STRING);              
               self.emit(D_QUOTES);
          }
          case '$': {              
               if (self.cursor.follows('{')) {
                    self.emit(INTERP_START);
                    self.ctxs.switch_to(INTERPOLATION);
                    break;
               }
               
               if (is_identifier_char(self.cursor.peek())) {     
                    self.emit(INTERP_IDENT);
                    self.lex_identifier();
               }                 
          }
          case ' ':
          case '\n': {
               if (self.ctx().mode == RAW) {
                    self.ctxs.switch_back();
                    self.lex_code(c)!;
                    break;
               }
               nextcase default;
          }
          case '\\':
          default: self.lex_string_text()!;    
     }
}


fn bool Lexer.is_string_breaker(&self)
{
     char c = self.cursor.peek();

     // Only a breaker when there's a possible identifier or start of a block" 
     if (c == '$') {
          char sc = self.cursor.peek(1);
          return sc == '{' || is_identifier_char(sc);
     }

     if (self.ctx().mode == RAW) {
          return ascii::is_space(c);          
     }
     
     return c == '\\' || c == '"'; 
}

fn bool is_identifier_char(char c)
{
     return ascii::is_alnum(c) || c == '_';
}

fn void? Lexer.lex_string_text(&self)
{ 
     while(!self.is_string_breaker()) self.cursor.advance();

     self.emit((self.ctx().mode == RAW)
          ? TokenKind.RAW
          : TokenKind.STRING_PART
     );
}

fn void Lexer.lex_space(&self, char c)
{
     switch (c) {
          case '\n': self.emit(NEW_LINE);
          default: self.emit(SPACE);
     }
}

fn void Lexer.lex_number(&self)
{
     TokenKind kind = INTEGER; 

     while (ascii::is_digit(
          self.cursor.peek()
     )) self.cursor.advance();

     if (self.cursor.peek() == '.') {
          kind = FLOAT;
          self.cursor.advance();

          while (ascii::is_digit(
               self.cursor.peek()
          )) self.cursor.advance();
     }
     self.emit(kind);
}


fn void Lexer.lex_identifier(&self)
{
     while (is_identifier_char(
          self.cursor.peek()
     )) self.cursor.advance();

     self.emit(check_keywords(
          self.cursor.captured()
     ));
}

fn void Lexer.lex_comment(&self)
{
     while(self.cursor.peek() != '\n') self.cursor.advance();
}
