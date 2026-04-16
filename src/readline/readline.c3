module cyqra::readline::reader;
import libc;
import std::os::linux;
import std::io;

import cyqra::readline::term;
import cyqra::readline::poll;
import cyqra::readline::line_buffer;

enum KeyCode {
    // printable
    CHAR,
    // whitespace / editing
    ENTER,
    TAB,
    BACKSPACE,
    DELETE,
    ESCAPE,
    // arrows
    UP,
    DOWN,
    LEFT,
    RIGHT,
    // navigation
    HOME,
    END,
    PAGE_UP,
    PAGE_DOWN,
    // ctrl+letter
    CTRL,
    // unknown
    UNKNOWN,
}
struct Event {
    KeyCode kind;
	// An utf8 char bytes
	char[4] ch;
	int len;
}

fn char[] read_event(char[] buffer)
{
	sz len = libc::read(libc::STDIN_FD, buffer, buffer.len);
	return buffer[:len];
}
fn Event parse_event(char[] buf)
{
    if (buf.len == 0) return {};
    
    char c = buf[0];
    switch (c) {
		case '\r':  return { .kind = ENTER };
        case '\t':  return { .kind = TAB };
        case 0x7f:  return { .kind = BACKSPACE };
        // escape sequence
        case 0x1b: {
		   	if (buf.len > 1 && buf[1] == '[') return parse_csi(buf[2..]);
            return { .kind = ESCAPE };
        }
        // ctrl keys
        case 0: return { .kind = CTRL, .ch[0] = ' ' };
		// case 0x1..0x8:
		// case 0xa..0xc:
		// case 0xe..0x1a:
			// return { .kind = CTRL, .ch[0] = c + '@' };
		// case 0x1c..0x1f: return { .kind = CTRL, .ch[0] = c - 0x1c + '4' };
		// utf8 chars
        default: {
			Event ev = { .kind = CHAR, .len = buf.len };
			mem::copy_inline(&ev.ch, buf, 4);
			return ev;
		};
    }
}

fn Event parse_csi(char[] buf)
{
    if (buf.len == 0) return {};
    switch (buf[0]) {
        case 'A': return { .kind = UP };
        case 'B': return { .kind = DOWN };
        case 'C': return { .kind = RIGHT };
        case 'D': return { .kind = LEFT };
        case 'H': return { .kind = HOME };
        case 'F': return { .kind = END };
		case '3': return { .kind = DELETE };
		default:  return { .kind = UNKNOWN };
    }
}

struct Reader
{
	Terminal term;
	char[8] buffer;
	Poll poll;
	LineBuffer line_buffer;
}

fn Reader new(Allocator allocator) @public => {
	.poll = poll::new(),
	.line_buffer = line_buffer::new(allocator)
};

fn void Reader.free(&self)
{
	self.line_buffer.free();
}

fn void Reader.render(&self) {
    String ps1 = "> ";
    DString out;
    out.init(tmem);
    // hide cursor
    out.append("\x1b[?25l");
    out.append("\r");
    // erase entire line
    out.append("\x1b[2K");
    out.appendf("%s%s", ps1, self.line_buffer.prompt);
    out.appendf("\x1b[%dG", ps1.len + self.line_buffer.visual_cursor + 1);
    // show cursor
    out.append("\x1b[?25h");

    io::stdout().write(out.str_view())!!;
    io::stdout().flush()!!;
}

<*
	@return "true on submit"
*>
fn bool Reader.handle_input(&self)
{
	char[] escape = read_event(&self.buffer);
	Event event = parse_event(escape);
	return self.consume_event(event);
}

fn bool Reader.consume_event(&self, Event event)
{
	switch (event.kind) {
		case LEFT:
			self.line_buffer.move("left");
		case RIGHT:
			self.line_buffer.move("right");
		case CHAR:
			self.line_buffer.insert(event.ch[:event.len]);
		case BACKSPACE:
			self.line_buffer.remove("left");
		case DELETE:
			self.line_buffer.remove("right");
		case ENTER:
			return true;	

		default:
			//insert
			io::printn(event);
	}
	return false;
}

fn String Reader.read_line(&self)
{
	self.line_buffer.reset();

	self.term.enable_raw();
	defer self.term.disable_raw();
	
	self.render();
	while (true) {
		if (!self.poll.tick()) continue;
		if (self.handle_input()) break;

		//! TODO: partial rerender?
		self.render();
	}
	return self.line_buffer.str();
}
