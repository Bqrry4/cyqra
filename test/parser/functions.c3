module cyqra::parser @test;

<* Declarations *>
fn void parse_fn_empty()
{
	Ast ast = parse(`
		fn test() {}
    `);
	Function* fun = unwrap_fn_decl(unwrap_nth(ast.expressions, 0), "test");
    assert_params(fun.params);
	Block* blk = unwrap_block(fun.body);
	assert(blk.stmts.len() == 0);
}
fn void parse_fn_with_params_body()
{
    Ast ast = parse(`
		fn sub(x, y) {
			x - y
		}
	`);
    Function* fun = unwrap_fn_decl(unwrap_nth(ast.expressions, 0), "sub");
    assert_params(fun.params, "x", "y");
	Block* blk = unwrap_block(fun.body);
	assert(blk.stmts.len() == 1);
	Infix* ifx = unwrap_infix(unwrap_nth(blk.stmts, 0), MINUS);
    assert_token(unwrap_primary(ifx.lhs), "x");
    assert_token(unwrap_primary(ifx.rhs), "y");
}
<* Calls *>
/* Fp style */
fn void parse_fn_call()
{
    Ast ast = parse(`
		let b = 3
		sub(b, 2)
	`);
	Call* call = unwrap_call(unwrap_nth(ast.expressions, 1));
	assert_token(unwrap_primary(call.callee), "sub");
	assert_token(unwrap_primary(unwrap_nth(call.args, 0)), "b");
	assert_token(unwrap_primary(unwrap_nth(call.args, 1)), "2");
}
/* Shell style */
fn void parse_shell_call()
{
    Ast ast = parse(`
		sub $b (2)
	`);
	Call* call = unwrap_call(unwrap_nth(ast.expressions, 0));
	assert_token(unwrap_primary(call.callee), "sub");
	StringLiteral* str = unwrap_string(unwrap_nth(call.args, 0));
	StringPart* part = unwrap_nth_str_part(str, 0, INTERP);
	assert_token(unwrap_primary(part.interp), "b");
	assert_token(unwrap_primary(unwrap_nth(call.args, 1)), "2");
}

