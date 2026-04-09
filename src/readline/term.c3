module cyqra::readline::term;
import libc::termios;

struct Terminal
{
	Termios state;
}

fn void Terminal.enable_raw(&self)
{
	// Save the og state of the terminal
    self.state.get_attr(libc::STDIN_FD);
	
	Termios raw = self.state;
    // Disable echo and line buffering
    raw.c_lflag.echo   = false;
	raw.c_lflag.icanon = false;
	
	raw.c_cc[Cc.VMIN]  = (Cc)1;
	raw.c_cc[Cc.VTIME] = (Cc)0;

    raw.set_attr(libc::STDIN_FD, TCSAFLUSH);
}

fn void Terminal.disable_raw(&self)
{
	self.state.set_attr(libc::STDIN_FD, TCSAFLUSH);
}
