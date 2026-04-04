module cyqra;
import std::io;
import std::os;
import std::collections::list;

import cyqra::lexer;
import cyqra::parser;
import cyqra::interpreter;

fn void interactive() => @pool()
{
    Interpreter interpreter = interpreter::new(tmem);
    Parser parser = parser::new(tmem, {.src_name = "repl"});
    while (true) {
        io::print("> ");
        // read
        String line = io::treadline()!!;

        Lexer lexer = lexer::new(tmem, line);
        List{Token} tokens = lexer.analyze();

        parser.parse(tokens);     
        interpreter.interpret(parser.ast);
   }
}

fn void from_file(String file_name, String content)
{
    
    Lexer lexer = lexer::new(tmem, content);
    List{Token} tokens = lexer.analyze();

     // foreach(t:tokens)
     // {
     //  io::print(t);   
     // }
    Parser parser = parser::new(tmem, {.src_name = file_name});
    parser.parse(tokens);

    // foreach(expr: parser.ast.expressions)
    // {
        // expr.print();
    // }
    
    Interpreter interpreter = interpreter::new(tmem);
    interpreter.interpret(parser.ast);
}

fn int main(String[] args)
{
    if(args.len == 2) {
        String s_path = args[1];
        char[]? file = file::load(tmem, s_path);
        from_file(s_path, (String)file!!);
    }
    else {
        interactive();
    }
 
    return 0;
}
