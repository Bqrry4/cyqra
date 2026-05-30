module cyqra::parser @test;

<* Declarations *>
fn void parse_fn_empty()
{
	Ast ast = parse(`
		fn test() {}
    `).ast;
	Function* fun = unwrap_fn_decl(unwrap_nth(ast.expressions, 0), "test");
    assert_params(fun.params);
	Block* blk = unwrap_block(fun.body);
	assert(blk.stmts.len() == 0);
}
fn void parse_fn_with_params_body()
{
    Parser p = parse(`
		fn sub(x, y) {
			x - y
		}
	`);
	Ast ast = p.ast;
    Function* fun = unwrap_fn_decl(unwrap_nth(ast.expressions, 0), "sub");
    assert_params(fun.params, "x", "y");
	Block* blk = unwrap_block(fun.body);
	assert(blk.stmts.len() == 1);
	Infix* ifx = unwrap_infix(unwrap_nth(blk.stmts, 0), SUB);
    assert_var(p.vars, ifx.lhs, "x");
    assert_var(p.vars, ifx.rhs, "y");
}
fn void parse_lambda_empty()
{
	//TODO!
	Ast ast = parse(`
		&{}
    `).ast;
}
<* Calls *>
/* Fp style */
fn void parse_fn_call()
{
    Parser p = parse(`
		let b = 3
		sub(b, 2)
	`);
	Ast ast = p.ast;
	Call* call = unwrap_call(unwrap_nth(ast.expressions, 1));
	assert_external(call.callee, "sub");
	assert_var(p.vars, unwrap_nth(call.args, 0), "b");
	assert_token(unwrap_primary(unwrap_nth(call.args, 1)), "2");
}
/* Shell style */
fn void parse_shell_call()
{
    Parser p = parse(`
		let b = 5
		sub $b (2)
	`);
	Ast ast = p.ast;
	Call* call = unwrap_call(unwrap_nth(ast.expressions, 1));
	assert_external(call.callee, "sub");
	StringLit* str = unwrap_string(unwrap_nth(call.args, 0));
	StringPart* part = unwrap_nth_str_part(str, 0, INTERP);
	assert_var(p.vars, part.interp, "b");
	assert_token(unwrap_primary(unwrap_nth(call.args, 1)), "2");
}

