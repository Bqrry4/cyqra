module cyqra::lexer::span;

struct Span
{
	usz column;
	usz row;
	String slice;
}

fn Span Span.extend(&self, Span after) {
	self.slice = (String)(self.slice.ptr)[:(after.slice.ptr - self.slice.ptr + after.slice.len)];
	return *self;
}
<*
	Backtrack n lines in the source
	@warning "Unsafe: assumes @span is valid and correctly bounded."
	@note "n == 0 will backtrack to the beginning of the current line"
	@return ```
		A new span, with a slice extended from n line behind to the given @span,
	```
*>
fn Span backtrack(String source, Span span, uint n)
{
	char* current = span.slice;
	uint lines = (uint)min(n, span.row);

	int remaining = lines;
	while (current > source.ptr) {
		--current;
		if (*current != '\n') continue;
		--remaining;
		if (remaining <= 0) {
			// Ended on a \n
			current++;
			break;
		}
	}
	return {
		.slice = (String)current[: (span.slice.ptr + span.slice.len - current)],
		.column = 0,
		.row = span.row - lines,
	};
}
