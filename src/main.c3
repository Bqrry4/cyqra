module cyqra;
import std::io;
import std::os;
import std::collections::list;

import cyqra::lexer;
import cyqra::parser;
import cyqra::interpreter;
import cyqra::readline::reader;

fn void interactive() => @pool()
{
    Lexer lexer = lexer::new(tmem);
    Parser parser = parser::new(tmem, {.src_name = "repl"});
    Interpreter interpreter = interpreter::new(tmem);
    Reader reader = reader::new(tmem);
    while (true) {
        String line = reader.read_line();
        //! TODO: implement proper render in the ^reader
        io::printf("\r\n");
        List{Token} tokens = lexer.analyze(line);

        parser.parse(tokens);     
        interpreter.interpret(parser.ast);
   }
}

fn void from_file(String file_name, String content)
{
    
    Lexer lexer = lexer::new(tmem);
    List{Token} tokens = lexer.analyze(content);

    Parser parser = parser::new(tmem, {.src_name = file_name});
    parser.parse(tokens);
   
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
