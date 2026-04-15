module cyqra::readline::line_buffer;
import std::io;
 
struct LineBuffer
{
	DString prompt;
	usz internal_cursor;
	usz visual_cursor;
}

fn LineBuffer new(Allocator allocator) => {
	.prompt = (DString){}.init(allocator)
};


macro sz LineBuffer.closest_codepoint(&self, $direction)
{
	usz cursor = self.internal_cursor;
	$switch $direction:
		$case "right":
			if (cursor >= self.prompt.len()) return 0;
			char c = self.prompt[cursor];
			switch {
				case (c < 0x80): return 1;
				case (c < 0xE0): return 2;
				case (c < 0xF0): return 3;
				default: return 4;
			}
		$case "left":
			do {
				if (cursor == 0) return 0;
				cursor--;
			} while ((self.prompt[cursor] & 0xC0) == 0x80);
			return (sz)cursor - self.internal_cursor;
		$endswitch	
}


macro LineBuffer.move(&self, $direction)
{
	sz diff = self.closest_codepoint($direction);
	if (!diff) return;
	
	self.internal_cursor += diff;
	$switch $direction:
		$case "left":
			self.visual_cursor--;
		$case "right":
			self.visual_cursor++;
	$endswitch
	
}
macro LineBuffer.move_by_word(&self, $direction)
{
	do {
		$if $direction == "left":
			if (self.internal_cursor == 0) return;
			self.internal_cursor--;
		$endif
		$if $direction == "right":
			if (self.internal_cursor >= self.prompt.len()) return;
			self.internal_cursor++;
			//@ Allow cursor to be off by 1 
			if (self.internal_cursor >= self.prompt.len()) return;
		$endif
	}
	while (self.prompt[self.internal_cursor] == ' ');
}
fn void LineBuffer.insert(&self, char[] chars)
{
	self.prompt.insert_chars_at(self.internal_cursor, (String)chars);
	self.internal_cursor += chars.len;
	self.visual_cursor += conv::utf8_codepoints((String)chars);
}
macro LineBuffer.remove(&self, $direction)
{
	sz diff = self.closest_codepoint($direction);
	if (!diff) return;

	$switch $direction:
		$case "left":
			self.prompt.delete_range(self.internal_cursor + diff, self.internal_cursor - 1);
			self.internal_cursor += diff;
			self.visual_cursor--;
		$case "right":
			self.prompt.delete_range(self.internal_cursor, self.internal_cursor + diff - 1);
	$endswitch
}
