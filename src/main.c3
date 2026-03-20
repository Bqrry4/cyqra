module cyqra;
import std::io;
import std::os;
import std::collections::list;

import cyqra::lexer;
import cyqra::parser;
import cyqra::interpreter;

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

fn void int_loop() => @pool()
{
    Interpreter interpreter = interpreter::new(tmem);

    while (true) {
        io::print("> ");
        // read
        String line = io::treadline()!!;

        Lexer lexer = lexer::new(tmem, line);
        List{Token} tokens = lexer.analyze();
        // foreach(t:tokens)
        // {
            // io::print(t);   
        // }
        
        Parser parser = parser::new(tmem, tokens);
        parser.parse();

        interpreter.interpret(parser.ast);
   }
}

fn int main()
{
    int_loop();

    return 0;
}
