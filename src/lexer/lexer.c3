module cyqra::lexer;
import std::collections::list;
import std::io;
import std::ascii;
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

fn Lexer new(Allocator allocator, String source) @public
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
          .source = source,
          .output = tokens,
          .cursor = {
               .start = source,
               .current = source,
               .end = (char*)source + source.len
          },
          .ctxs = ctxs
     };
}


fn void List{ LexContext }.switch_to(&self, Mode mode) => self.push({
     .mode = mode
});
fn void List{ LexContext }.switch_back(&self) => self.pop()!!;

fn LexContext* Lexer.ctx(&self) => &self.ctxs[self.ctxs.len() - 1];

fn List{ Token } Lexer.analyze(&self)
{
     while (!self.cursor.eof()) {
         if (catch self.next_token()) break;
     }
    
     return self.output;
}

 
fn void Lexer.mk_token(&self, TokenKind kind)
{
     String lexeme = self.cursor.captured();
     self.output.push({
          .kind = kind,
          .value = lexeme
     });

     self.cursor.sync_start();
}


fn void? Lexer.next_token(&self)
{
     char c = self.cursor.advance()!;
     switch MODE: (self.ctx().mode) {
          case DEFAULT:
          case INTERPOLATION: switch(c) {
               case '+': self.cursor.follows('+') ? self.mk_token(PLUS_PLUS)
                         : self.cursor.follows('=') ? self.mk_token(PLUS_ASGN)
                                             : self.mk_token(PLUS);
               case '-': self.cursor.follows('-') ? self.mk_token(MINUS_MINUS)
                         : self.cursor.follows('=') ? self.mk_token(MINUS_ASGN)
                                             : self.mk_token(MINUS);
               case '*': self.cursor.follows('*') ? self.mk_token(STAR_STAR)
                         : self.cursor.follows('=') ? self.mk_token(STAR_ASGN)
                                             : self.mk_token(STAR);
               case '/': self.cursor.follows('=') ? self.mk_token(SLASH_ASGN)
                                           : self.mk_token(SLASH);
               case '%': self.mk_token(PERCENT);
               case '|': self.cursor.follows('@') ? self.mk_token(PIPE_ALL)
                                           : self.mk_token(PIPE);
               case '<': self.cursor.follows('=') ? self.mk_token(LTE)
                                           : self.mk_token(LT);
               case '>': self.cursor.follows('=') ? self.mk_token(GTE)
                                           : self.mk_token(GT);
               case '=': self.cursor.follows('=') ? self.mk_token(ASGN)
                                           : self.mk_token(EQ);
               case '!': self.cursor.follows('=') ? self.mk_token(NEQ)
                                           : self.mk_token(EXCLAMATION);
               case '(': self.mk_token(OPEN_PHARANTESIS);
               case ')': self.mk_token(CLOSED_PHARANTESIS);
               case '[': self.mk_token(OPEN_BRACKET);
               case ']': self.mk_token(CLOSED_BRACKET);
               case '{': {
                    if (self.ctx().mode != INTERPOLATION) {
                            self.mk_token(OPEN_BRACE);
                    }

                    self.ctx().interp.brace_depth++;                  
               }
               case '}': {
                    if (self.ctx().mode != INTERPOLATION) {
                         self.mk_token(CLOSED_BRACE);
                         break;
                    }

                    if (self.ctx().interp.brace_depth == 0) {
                         self.mk_token(INTERP_END);
                         self.ctxs.switch_back();
                         break;
                    }

                    self.ctx().interp.brace_depth--;
               }
               case ';': self.mk_token(SEMICOLON);
               case ',': self.mk_token(COMMA);
               case '\0': self.mk_token(EOF);
               case '"': {
                    self.ctxs.switch_to(STRING);              
                    self.mk_token(D_QUOTES);
               }                    
              default: switch {
                         case ascii::is_space_m(c): self.lex_space(c);
                         case ascii::is_digit_m(c): self.lex_number()!;
                         case is_identifier_char(c): self.lex_identifier()!;
                         default: {
                              self.ctxs.switch_to(RAW);
                              nextcase MODE: RAW;
                         }
               }
          }
          case STRING:
          case RAW: switch (c) {
               case '"': {
                    if (self.ctx().mode == STRING) {
                         self.ctxs.switch_back();
                         self.mk_token(D_QUOTES);
                         break;
                    }
                    self.ctxs.switch_to(STRING);              
                    self.mk_token(D_QUOTES);
               }
               case '$': {              
                    if (self.cursor.follows('{')) {
                         self.mk_token(INTERP_START);
                         self.ctxs.switch_to(INTERPOLATION);
                         break;
                    }
                    
                    if (is_identifier_char(self.cursor.peek()!)) {     
                         self.mk_token(INTERP_IDENT);
                         self.lex_identifier()!;
                    }                 
               }
               case ' ': {
                    if (self.ctx().mode == RAW) {
                         self.ctxs.switch_back();
                         nextcase MODE: DEFAULT;
                    }
               }
               case '\\':
               default: self.lex_string_text()!;    
          }    
     }
 }

fn bool? Lexer.is_string_breaker(&self)
{
     char c = self.cursor.peek()!;

     // Only a breaker when there's a possible identifier
     if (c == '$') {
          if (try sc = self.cursor.peek(1)) {
               return is_identifier_char(sc);
          }
          return false;
     }

     if (self.ctx().mode == RAW) {
          return ascii::is_space_m(c);          
     }
     
     return c == '\\' || c == '"'; 
}

fn bool is_identifier_char(char c)
{
     return ascii::is_alnum_m(c) || c == '_';
}

fn void? Lexer.lex_string_text(&self)
{
     defer self.mk_token(
          (self.ctx().mode == RAW) ? TokenKind.RAW
                             : TokenKind.STRING_PART
     );

     while(!self.is_string_breaker()!) self.cursor.advance()!;
}

fn void Lexer.lex_space(&self, char c)
{
     switch (c) {
          case '\n': self.mk_token(NEW_LINE);
          default: self.mk_token(SPACE);
     }
}

fn void? Lexer.lex_number(&self)
{
     TokenKind kind = INTEGER;

     defer self.mk_token(kind);

     while (ascii::is_digit_m(self.cursor.peek()!)) self.cursor.advance()!;
     if (self.cursor.peek()! == '.') {
          kind = FLOAT;
          self.cursor.advance()!;
          while (ascii::is_digit_m(self.cursor.peek()!)) self.cursor.advance()!;
     }
}


fn void? Lexer.lex_identifier(&self)
{
   
     defer if(catch self.check_keywords()) {
          self.mk_token(IDENTIFIER);
     }

     while(is_identifier_char(self.cursor.peek()!)) self.cursor.advance()!;
  }

fn void? Lexer.check_keywords(&self)
{
     switch {
          case !libc::memcmp(self.cursor.start, "let", 3): self.mk_token(LET);
          case !libc::memcmp(self.cursor.start, "mut", 3): self.mk_token(MUT);
          case !libc::memcmp(self.cursor.start, "env", 3): self.mk_token(ENV);
          case !libc::memcmp(self.cursor.start, "alias", 5): self.mk_token(ALIAS);
          case !libc::memcmp(self.cursor.start, "fn", 2): self.mk_token(FN);
          case !libc::memcmp(self.cursor.start, "if", 2): self.mk_token(IF);
          case !libc::memcmp(self.cursor.start, "else", 4): self.mk_token(ELSE);
          case !libc::memcmp(self.cursor.start, "while", 5): self.mk_token(WHILE);
          default: return NOT_FOUND~;
     }
}
