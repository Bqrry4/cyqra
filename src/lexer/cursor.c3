module cyqra::lexer::cursor;

faultdef REACHED_EOF;

struct Cursor
{
     char* start;
     char* current;
     char* end;
}

fn bool Cursor.eof(&self, int n = 0) => (self.current >= self.end);
fn char? Cursor.advance(&self)
{
     if(self.eof()) return REACHED_EOF~;
     return *(self.current++); 
}
fn char? Cursor.peek(&self, int n = 0)
{
     if(self.eof(n)) return REACHED_EOF~;
     return *(self.current + n);  
} 
fn bool Cursor.follows(&self, char expect)
{
     char? c = self.peek();
     if (catch c) return false;
     bool follows = (c == expect);
     if (follows) self.current++;
     return follows;
}
fn void Cursor.sync_start(&self)
{
     self.start = self.current;
}
fn String Cursor.captured(&self) => (String)self.start[
     ..self.current - self.start - 1
];
