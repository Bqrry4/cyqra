module cyqra::parser @test;
import cyqra::lexer;
import std::collections::list;

macro parse(String content)
{
	Lexer lexer = lexer::new(tmem);
    Parser parser = parser::new(tmem, &&{.src_name = "test"});

	parser.parse(lexer.analyze(content));
	return parser.ast;
}
macro Expr* unwrap_nth(List{ Expr* } exprs, uint n)
{
    assert(exprs.len() > n,
        "Expected at least %d expressions got %d", n + 1, exprs.len());
    return exprs[n];
}
macro void assert_token(Primary* p, String value)
{
    assert(p.token.span.slice == value,
        "token '%s' got '%s'", value, p.token.span.slice);
}
macro Primary* unwrap_primary(Expr* expr)
{
    assert(expr.kind == PRIMARY, "PRIMARY != %s", expr.kind);
    return &expr.primary;
}
macro Infix* unwrap_infix(Expr* expr, Operator op)
{
    assert(expr.kind == INFIX, "INFIX != %s", expr.kind);
    assert(expr.infix.op == op, "op %s != %s", op, expr.infix.op);
    return &expr.infix;
}
macro Function* unwrap_fn_decl(Expr* expr, String name)
{
    assert(expr.kind == FUNCTION, "FUNCTION != %s", expr.kind);
    assert(expr.fun.identifier.span.slice == name,
        "function name '%s' got '%s'", name, expr.fun.identifier.span.slice);
    return &expr.fun;
}
macro void assert_params(List {String} params, ...)
{
    assert(params.len() == $vaarg.len,
        "Expected %d params got %d", $vaarg.len, params.len());
	$for var $i = 0; $i < $vaarg.len; $i++:
        assert(params[$i] == $vaarg[$i]);
    $endfor  
}
macro Block* unwrap_block(Expr* expr)
{
    assert(expr.kind == BLOCK, "BLOCK != %s", expr.kind);
    return &expr.block;
}
macro Call* unwrap_call(Expr* expr)
{
    assert(expr.kind == CALL, "CALL != %s", expr.kind);
    return &expr.call;    
}
macro StringLit* unwrap_string(Expr* expr)
{
    assert(expr.kind == STRINGLIT, "STRING != %s", expr.kind);
    return &expr.string;        
}
macro StringPart* unwrap_nth_str_part(StringLit* str, uint n, StringPartKind expected)
{
    assert(str.parts.len() > n,
        "Expected at least %d parts in string got %d", n + 1, str.parts.len());
    StringPart* part = &str.parts[n];
    assert(part.kind == expected);
    return part;
}
macro Prefix* unwrap_prefix(Expr* expr, Operator op)
{
    assert(expr.kind == PREFIX);
    assert(expr.prefix.op == op);
    return &expr.prefix;
}
macro Postfix* unwrap_postfix(Expr* expr, Operator op)
{
    assert(expr.kind == POSTFIX);
    assert(expr.postfix.op == op);
    return &expr.postfix;
}
macro Array* unwrap_array(Expr* expr)
{
    assert(expr.kind == ARRAY);
    return &expr.array;
}
macro Record* unwrap_record(Expr* expr)
{
    assert(expr.kind == RECORD);
    return &expr.record;
}
macro Index* unwrap_index(Expr* expr)
{
    assert(expr.kind == INDEX);
    return &expr.index;
}
macro Pipeline* unwrap_pipeline(Expr* expr)
{
    assert(expr.kind == PIPELINE);
    return &expr.pipeline;
}
