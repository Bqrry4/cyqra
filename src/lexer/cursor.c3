module cyqra::lexer::cursor;
import cyqra::lexer::span;

struct Cursor
{
     char* start;
     char* current;
     char* end;

     uint line;
     uint column;

     uint start_line;
     uint start_column;
}

fn bool Cursor.eof(&self, int n = 0) => (self.current >= self.end);
fn char Cursor.advance(&self)
{
     if(self.eof()) return '\0';

     char c = *(self.current++);
     if (c == '\n') {
          self.line++;
          self.column = 1;
     }
     else {
          self.column++;
     }

     return c; 
}
fn char Cursor.peek(&self, int n = 0)
{
     if(self.eof(n)) return '\0';
     return *(self.current + n);  
} 
fn bool Cursor.follows(&self, char expect)
{
     char? c = self.peek();
     bool follows = @ok(c) && (c!! == expect);
     if (follows) self.current++;
     return follows;
}
fn void Cursor.sync_start(&self)
{
     self.start = self.current;
     self.start_column = self.column;
     self.start_line = self.line;
}
fn String Cursor.captured(&self) => (String)self.start[
     :self.current - self.start
];

fn Span Cursor.captured_span(&self) => {
     .slice = self.captured(),
     .row = self.start_line,
     .column = self.start_column,
};
