module cyqra::sema @test;
import cyqra::ast;
import cyqra::parser;

fn void parse_external_call()
{
	Ast ast = resolve(`
		echo -e Hello Cyqra	
	`);
	Call* call = parser::unwrap_call(ast.expressions[0]);
	assert_external(call.callee, "echo");
	parser::assert_static_string(call.args[0], "-e");
	parser::assert_static_string(call.args[1], "Hello");
	parser::assert_static_string(call.args[2], "Cyqra");
}
fn void parse_var_fn()
{
	Ast ast = resolve(`
		let print = &{|name| echo -e Hello $name };
		print Cyqra
	`);
	Binding* bnd = parser::unwrap_binding(ast.expressions[0]);
	Call* call = parser::unwrap_call(ast.expressions[1]);
	assert_var(call.callee, bnd.typed_name.ident.id);
	parser::assert_static_string(call.args[0], "Cyqra");	
}
fn void parse_var_expr()
{
	Ast ast = resolve(`
		let echo = 0
		echo - echo
	`);
	Binding* bnd = parser::unwrap_binding(ast.expressions[0]);
	Infix* ifx = unwrap_infix(ast.expressions[1], SUB);
	assert_var(ifx.lhs, bnd.typed_name.ident.id);
	assert_var(ifx.rhs, bnd.typed_name.ident.id);
}

fn void parse_expr_with_shell_call()
{
	Ast ast = resolve(`
		let echo = 0
		echo - ls
	`);
	Binding* bnd = parser::unwrap_binding(ast.expressions[0]);
	Infix* ifx = unwrap_infix(ast.expressions[1], SUB);
	assert_var(ifx.lhs, bnd.typed_name.ident.id);
	Call* call = parser::unwrap_call(ifx.rhs);
	assert_external(call.callee, "ls");
}
