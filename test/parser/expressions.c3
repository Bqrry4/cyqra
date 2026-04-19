module cyqra::parser @test;

fn void parse_infix()
{
    Ast ast = parse(`
		3 + 6
    `);
    Infix* infix = unwrap_infix(unwrap_nth(ast.expressions, 0), PLUS);
    assert_token(unwrap_primary(infix.lhs), "3");
    assert_token(unwrap_primary(infix.rhs), "6");
}

fn void parse_precedence()
{
    // 1 + 2 * 3  →  1 + (2 * 3)
    Ast ast = parse(`
        1 + 2 * 3
    `);
    Infix* add = unwrap_infix(unwrap_nth(ast.expressions, 0), PLUS);
    assert_token(unwrap_primary(add.lhs), "1");

    Infix* mul = unwrap_infix(add.rhs, STAR);
    assert_token(unwrap_primary(mul.lhs), "2");
    assert_token(unwrap_primary(mul.rhs), "3");
}

fn void parse_nested()
{
    Ast ast = parse("1 + (2 + 3)");
    Infix* outer = unwrap_infix(unwrap_nth(ast.expressions, 0), PLUS);
    assert_token(unwrap_primary(outer.lhs), "1");
    Infix* inner = unwrap_infix(outer.rhs, PLUS);
    assert_token(unwrap_primary(inner.lhs), "2");
    assert_token(unwrap_primary(inner.rhs), "3");
}
