module utils;

// fn void set_env(String name, String value) {
//     // "NAME=VALUE\0" — putenv takes ownership on some platforms, so use a static/long-lived buffer
//     ZString entry = string::tformat("%s=%s", name, value).ptr;
//     libc::putenv(entry);
// }
