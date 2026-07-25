module cyqra::parser @test;
import cyqra::lexer;
import cyqra::ast;
import std::collections::list;
import utils::nullable;
import std::io;

macro parse(String content) => mem::@scoped(tmem)
{
	Lexer lexer = lexer::new();
    Parser parser = parser::new(&&{.src_name = "test"});

   	Ast ast = ast::new();
   	FnDecl fn_decl; fn_decl.init(mem);

    parser.cursor.tokens = lexer.analyze(content).array_view();
    parser.cursor.reset();
    parser.parse(&ast, &fn_decl);
	return ast;
}

macro assert_kind(Expr* e, ExprKind kind)
{
    assert(e.kind == kind, "%s != %s", kind, e.kind);
}

macro Expr* unwrap_nth(List{ Expr* } exprs, uint n)
{
    assert(exprs.len() > n,
        "Expected at least %d expressions got %d", n + 1, exprs.len());
    return exprs[n];
}
macro unwrap_literal(Expr* e)
{
    assert_kind(e, LITERAL);
    return &e.literal;
}
macro assert_int(Expr* e, long v)
{
    Literal* l = unwrap_literal(e);
    assert(l.type == INT);
    assert(l._int == v);
}
macro assert_float(Expr* e, double v)
{
    Literal* l = unwrap_literal(e);
    assert(l.type == FLOAT);
    assert(l._float == v);
}
macro assert_ident(Expr* e, String name)
{
    assert_kind(e, IDENTIFIER);
    assert(e.ident.name == name);
}
macro assert_ambiguous_ident(Expr* e, String name)
{
    assert_kind(e, AMBIGUOUS_IDENT);
    assert(e.amb_ident.name == name);
}
macro assert_op(Expr* e, Operator op)
{
    assert_kind(e, OPERATOR);
    assert(e.op == op);
}
macro assert_static_string(Expr* e, String v)
{
    Literal* l = unwrap_literal(e);
    assert(l.type == STRING);
    assert(l._string.kind == STATIC);
    io::printf("String: %s", l._string.static_str);
    assert(l._string.static_str == v);
}
macro unwrap_fseq(Expr* e)
{
    assert_kind(e, FLAT_SEQUENCE);
    // fseq never wraps a singleton
    assert(e.fseq.len() > 1);
    return &e.fseq;
}
macro Function* unwrap_fn_decl(
    Expr* e, String name,
    Nullable{ Expr* } type = nullable::NULL
){
    assert_kind(e, FUNCTION);
    String fname = e.fun.typed_name.ident.name;
    assert(fname == name,
        "function name '%s' got '%s'", name, fname);
    // assert(type == e.fun.typed_name.type);
    return &e.fun;
}
macro void assert_params(List {String} params, ...)
{
    assert(params.len() == $vaarg.len,
        "Expected %d params got %d", $vaarg.len, params.len());
	$for var $i = 0; $i < $vaarg.len; $i++:
        assert(params[$i] == $vaarg[$i]);
    $endfor  
}
// macro Block* unwrap_block(Expr* expr)
// {
//     assert(expr.kind == BLOCK, "BLOCK != %s", expr.kind);
//     return &expr.block;
// }
macro Call* unwrap_call(Expr* e)
{
    assert_kind(e, CALL);
    return &e.call;
}
macro LiteralString* unwrap_string(Expr* e)
{
    Literal* l = unwrap_literal(e);
    assert(l.type == STRING);
    return &expr.string;        
}
macro unwrap_field(Expr* e)
{
    assert_kind(e, FIELD);
    return &e.field;
}
macro unwrap_binding(Expr* e)
{
    assert_kind(e, BINDING);
    return &e.bnd;
}// macro StringPart* unwrap_nth_str_part(StringLit* str, uint n, StringPartKind expected)
// {
//     assert(str.parts.len() > n,
//         "Expected at least %d parts in string got %d", n + 1, str.parts.len());
//     StringPart* part = &str.parts[n];
//     assert(part.kind == expected);
//     return part;
// }
// macro Prefix* unwrap_prefix(Expr* expr, Operator op)
// {
//     assert(expr.kind == PREFIX);
//     assert(expr.prefix.op == op);
//     return &expr.prefix;
// }
// macro Postfix* unwrap_postfix(Expr* expr, Operator op)
// {
//     assert(expr.kind == POSTFIX);
//     assert(expr.postfix.op == op);
//     return &expr.postfix;
// }
macro LiteralList* unwrap_list(Literal* l)
{
    assert(l.type == LIST);
    return &l._list;
}
macro LiteralRecord* unwrap_record(Literal* l)
{
    assert(l.type == RECORD);
    return &l._record;
}
macro Index* unwrap_index(Expr* e)
{
    assert_kind(e, INDEX);
    return &e.idx;
}
macro Pipeline* unwrap_pipeline(Expr* e)
{
    assert_kind(e, PIPELINE);
    return &e.ppln;
}
// macro Collect* unwrap_collect(Expr* expr)
// {
//     assert(expr.kind == COLLECT);
//     return &expr.collect;
// }
// macro Variable* unwrap_var(Expr* expr)
// {
//     assert(expr.kind == VARIABLE);
//     return &expr.variable;
// }
// macro assert_var(VarPool vars, Expr* expr, String name)
// {
//     assert(vars.name_of(unwrap_var(expr).id) == name);
// }
