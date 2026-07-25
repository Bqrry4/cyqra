module cyqra::sema @test;
import cyqra::lexer;
import cyqra::parser;
import cyqra::ast;
import cyqra::diagnostic;

macro resolve(String content) => mem::@scoped(tmem)
{
	Diagnostic diag = {.src_name = "test"};
	Lexer lexer = lexer::new();
	Parser parser = parser::new(&diag);
	Sema sema = sema::new(&diag);
	
   	Ast ast = ast::new();
   	FnDecl fn_decl; fn_decl.init(mem);

    parser.cursor.tokens = lexer.analyze(content).array_view();
    parser.cursor.reset();
    parser.parse(&ast, &fn_decl);
	sema.register_signatures(fn_decl);
	sema.resolve(&ast);
	return ast;
}

macro assert_external(Expr* e, String name)
{
    parser::assert_kind(e, EXTERNAL);
    assert(e.external.name == name);
}
macro assert_var(Expr* e, SymbolID id)
{
    parser::assert_kind(e, VARIABLE);
    assert(e.variable.id == id);
}
macro unwrap_infix(Expr* e, Operator op)
{
	parser::assert_kind(e, INFIX);
	assert(e.infix.op == op);
	return &e.infix;
}
