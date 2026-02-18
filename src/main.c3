module cyqra;
import std::io;
import std::os;
import cyqra::lexer;
import std::collections::list;

fn String[] parse(String *line)
{
    return line.tsplit(" ");
}

fn void exec(String[] args)
{
    SubProcess? child = std::os::process::create(args, { .inherit_stdio = true });
    if (catch err = child)
    {
        io::printn("err");
    }
    (void)child.join();
}

fn void int_loop() => @pool() {
    while (true) {
        io::print("> ");
        // read
        String line = io::treadline()!!;

        List{Token} a;
        a.init(tmem);
        List{Token} tokens = lexer::lex(line, a);

        foreach(token : tokens)
        {
            io::printn(token);
        }
        
        // parse
        // String[] args = parse(&line);
        // execute
        // exec(args);          
    }
}

fn int main()
{
   int_loop();

    return 0;
}
