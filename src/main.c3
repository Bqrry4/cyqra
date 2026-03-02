module cyqra;
import std::io;
import std::os;
import cyqra::lexer;
import cyqra::parser;
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

        Lexer lexer = lexer::new(tmem, line);
        List{Token} tokens = lexer.analyze();
        // foreach(t:tokens)
        // {
        //  io::print(t);   
        // }
        
        Parser parser = parser::new(tmem, tokens);
        parser.parse();
        // execute
        // exec(args);          
    }
}

fn int main()
{
    int_loop();

    return 0;
}
