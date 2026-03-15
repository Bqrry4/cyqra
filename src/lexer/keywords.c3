module cyqra::lexer;

struct Keyword {
     String lexeme;
     TokenKind kind;
}

const Keyword[] KEYWORDS = {
    { "let",   LET   },
    { "mut",   MUT   },
    { "env",   ENV   },
    { "alias", ALIAS },
    { "fn",    FN    },
    { "if",    IF    },
    { "else",  ELSE  },
    { "while", WHILE },
};

fn TokenKind check_keywords(String word)
{
     foreach (kw: KEYWORDS) {
          if (word == kw.lexeme) {
               return kw.kind;
          }
     }
     return IDENTIFIER;
}

