module cyqra::readline;
import libc;
import std::os::linux;
import std::io;

fn void read_char()
{
	char c;
	libc::read(libc::STDIN_FD, &c, 1);
	io::printn(c);
}

fn void read_line()
{
	Terminal term;
	term.enable_raw();
	defer term.disable_raw();
	Poll poll = poll::new();
	while (true) {
		if (poll.poll()) {
			read_char();		
		}		
	}
}
