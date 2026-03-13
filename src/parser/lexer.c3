module cyqra::lexer;
import std::collections::list;
import std::io;
import std::ascii;
import libc;

faultdef REACHED_EOF;

enum Mode
{
     DEFAULT,
     STRING,
     INTERPOLATION,
     RAW
}

struct Lexer
{
     Allocator allocator;

     String source;
     List{ Token } output;

     char* tk_start;
     char* tk_current;

     Mode mode;
     List{ Mode } mode_stack;

     <* Needed for interpolation *>
     uint brace_depth;
}

fn Lexer new(Allocator allocator, String source) @public
{
     List{ Token } tokens;
     tokens.init(allocator);
     List{ Mode } stack;
     stack.init(allocator);
     
     return {
          .allocator = allocator,
          .source = source,
          .output = tokens,
          .tk_start = source,
          .tk_current = source,
          .mode = DEFAULT,
          .mode_stack = stack,
          .brace_depth = 0,
     };
}


fn void Lexer.switch_to(&self, Mode mode)
{
     self.mode_stack.push(self.mode);
     self.mode = mode;
}

fn void Lexer.switch_back(&self)
{
     self.mode = self.mode_stack.pop()!!;    
}

fn List{ Token } Lexer.analyze(&self)
{
     while (!self.eof()) {
         if (catch self.next_token()) break;
     }
    
     return self.output;
}


<* Returns the character currently pointed by the @tk_current, then inc it *>
fn char? Lexer.advance(&self)
{
     if(self.eof()) return REACHED_EOF~;
     return *(self.tk_current++); 
} 
fn char? Lexer.peek(&self, int n = 0)
{
     if(self.eof(n)) return REACHED_EOF~;
     return *(self.tk_current + n);  
} 
fn bool Lexer.follows(&self, char expect)
{
     char? c = self.peek();
     if (catch c) return false;
     return (c == expect) && self.tk_current++;
} 
fn bool Lexer.eof(&self, int n = 0) => (self.tk_current >= (void*)self.source + self.source.len + n);

fn void Lexer.mk_token(&self, TokenKind kind)
{
     self.output.push({
          .kind = kind,
          .value = (String)self.tk_start[
               ..self.tk_current - self.tk_start - 1
          ]
     });
     
     self.tk_start = self.tk_current;
}


fn void? Lexer.next_token(&self)
{
     char c = self.advance()!;
     switch MODE: (self.mode) {
          case DEFAULT:
          case INTERPOLATION: switch(c) {
               case '+': self.follows('+') ? self.mk_token(PLUS_PLUS)
                         : self.follows('=') ? self.mk_token(PLUS_ASGN)
                                             : self.mk_token(PLUS);
               case '-': self.follows('-') ? self.mk_token(MINUS_MINUS)
                         : self.follows('=') ? self.mk_token(MINUS_ASGN)
                                             : self.mk_token(MINUS);
               case '*': self.follows('*') ? self.mk_token(STAR_STAR)
                         : self.follows('=') ? self.mk_token(STAR_ASGN)
                                             : self.mk_token(STAR);
               case '/': self.follows('=') ? self.mk_token(SLASH_ASGN)
                                           : self.mk_token(SLASH);
               case '%': self.mk_token(PERCENT);
               case '|': self.follows('@') ? self.mk_token(PIPE_ALL)
                                           : self.mk_token(PIPE);
               case '<': self.follows('=') ? self.mk_token(LTE)
                                           : self.mk_token(LT);
               case '>': self.follows('=') ? self.mk_token(GTE)
                                           : self.mk_token(GT);
               case '=': self.follows('=') ? self.mk_token(ASGN)
                                           : self.mk_token(EQ);
               case '!': self.follows('=') ? self.mk_token(NEQ)
                                           : self.mk_token(EXCLAMATION);
               case '(': self.mk_token(OPEN_PHARANTESIS);
               case ')': self.mk_token(CLOSED_PHARANTESIS);
               case '[': self.mk_token(OPEN_BRACKET);
               case ']': self.mk_token(CLOSED_BRACKET);
               case '{': {
                    if (self.mode != INTERPOLATION) {
                            self.mk_token(OPEN_BRACE);
                    }

                    self.brace_depth++;                  
               }
               case '}': {
                    if (self.mode != INTERPOLATION) {
                         self.mk_token(CLOSED_BRACE);
                         break;
                    }

                    if (self.brace_depth == 0) {
                         self.mk_token(INTERP_END);
                         self.switch_back();
                         break;
                    }

                    self.brace_depth--;
               }
               case ';': self.mk_token(SEMICOLON);
               case ',': self.mk_token(COMMA);
               case '\0': self.mk_token(EOF);
               case '"': {
                    self.switch_to(STRING);              
                    self.mk_token(D_QUOTES);
               }                    
              default: switch {
                         case ascii::is_space_m(c): self.lex_space(c);
                         case ascii::is_digit_m(c): self.lex_number()!;
                         case is_identifier_char(c): self.lex_identifier()!;
                         default: {
                              self.switch_to(RAW);
                              nextcase MODE: RAW;
                         }
               }
          }
          case STRING:
          case RAW: switch (c) {
               case '"': {
                    if (self.mode == STRING) {
                         self.switch_back();
                         self.mk_token(D_QUOTES);
                         break;
                    }
                    self.switch_to(STRING);              
                    self.mk_token(D_QUOTES);
               }
               case '$': {              
                    if (self.follows('{')) {
                         self.mk_token(INTERP_START);
                         self.switch_to(INTERPOLATION);
                         break;
                    }
                    
                    if (is_identifier_char(self.peek()!)) {     
                         self.mk_token(INTERP_IDENT);
                         self.lex_identifier()!;
                    }                 
               }
               case ' ': {
                    if (self.mode == RAW) {
                         self.switch_back();
                         io::printn(self.mode);
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
     char c = self.peek()!;

     // Only a breaker when there's a possible identifier
     if (c == '$') {
          if (try sc = self.peek(1)) {
               return is_identifier_char(sc);
          }
          return false;
     }

     if (self.mode == RAW) {
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
          (self.mode == RAW) ? TokenKind.RAW
                             : TokenKind.STRING_PART
     );

     while(!self.is_string_breaker()!) self.advance()!;
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

     while (ascii::is_digit_m(self.peek()!)) self.advance()!;
     if (self.peek()! == '.') {
          kind = FLOAT;
          self.advance()!;
          while (ascii::is_digit_m(self.peek()!)) self.advance()!;
     }
}


fn void? Lexer.lex_identifier(&self)
{
   
     defer if(catch self.check_keywords()) {
          self.mk_token(IDENTIFIER);
     }

     while(is_identifier_char(self.peek()!)) self.advance()!;
  }

fn void? Lexer.check_keywords(&self)
{
     switch {
          case !libc::memcmp(self.tk_start, "let", 3): self.mk_token(LET);
          case !libc::memcmp(self.tk_start, "mut", 3): self.mk_token(MUT);
          case !libc::memcmp(self.tk_start, "env", 3): self.mk_token(ENV);
          case !libc::memcmp(self.tk_start, "alias", 5): self.mk_token(ALIAS);
          case !libc::memcmp(self.tk_start, "fn", 2): self.mk_token(FN);
          case !libc::memcmp(self.tk_start, "if", 2): self.mk_token(IF);
          case !libc::memcmp(self.tk_start, "else", 2): self.mk_token(ELSE);
          case !libc::memcmp(self.tk_start, "while", 5): self.mk_token(WHILE);
          default: return NOT_FOUND~;
     }
}
