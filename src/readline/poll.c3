module cyqra::readline::poll;
import libc;
import std::os::linux;

const POLL_WAIT = 100;

struct Poll
{
	int efd;
}

//! TODO: error handling and reporting
fn Poll new()
{
	int efd = linux::epoll_create1(0);
	
	int err = linux::epoll_ctl(efd,
		linux::EPOLL_CTL_ADD, libc::STDIN_FD,
		&&{ .events = linux::EPOLLIN, .data.fd = libc::STDIN_FD }
	);
	
	return {
		.efd = efd	
	};
}

fn bool Poll.poll(&self)
{
	EpollEvent event;
	return linux::epoll_wait(
		self.efd, &event, 1, POLL_WAIT
	) > 0;
}
