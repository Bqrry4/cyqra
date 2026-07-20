module cyqra;
import std::io;
import std::os;
import std::collections::list;

import cyqra::lexer;
import cyqra::parser;
// import cyqra::interpreter;
import cyqra::readline::reader;
import cyqra::core;

fn void interactive() => @pool()
{
    Diagnostic diag = {
        .src_name = "repl"
    };

    Reader reader @noinit;
    Lexer lexer @noinit;
    Parser parser @noinit;
    mem::@scoped(core::arena::alloc){
    	Ast ast = ast::new();
        reader = reader::new();
        lexer = lexer::new();
        parser = parser::new(&diag);
       // Interpreter interpreter = interpreter::new(tmem, &diag);

    	FnDecl fn_decl; fn_decl.init(mem);
        while (true) {
            String line = reader.read_line();
            //! TODO: implement proper render in the ^reader
            io::printf("\r\n");
            List{Token} tokens = lexer.analyze(line);
             
            diag.source = line;
            parser.cursor.tokens = tokens.array_view();
            parser.cursor.reset();
            parser.parse(&ast, &fn_decl);
            // interpreter.interpret(parser.ast);
         }
     };
}

fn void from_file(String file_name, String content)
{
    Diagnostic diag = {
        .src_name = file_name,
        .source = content
    };

    Lexer lexer @noinit;
    Parser parser @noinit;
    mem::@scoped(core::arena::alloc) {
        lexer = lexer::new();
        parser = parser::new(&diag);

    	Ast ast = ast::new();
        FnDecl fn_decl; fn_decl.init(mem);

        List{Token} tokens = lexer.analyze(content);
        
        parser.cursor.tokens = tokens.array_view();
        parser.cursor.reset(); 
        parser.parse(&ast, &fn_decl);
    };

    // Interpreter interpreter = interpreter::new(tmem, &diag);
    // interpreter.interpret(parser.ast);
}

fn int main(String[] args)
{
    core::arena::init();
    
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
