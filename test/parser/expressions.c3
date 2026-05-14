module cyqra::parser @test;

// --- arithmetic ---
fn void parse_infix_add()
{
    Ast ast = parse(`
		3 + 6
    `);
    Infix* infix = unwrap_infix(unwrap_nth(ast.expressions, 0), ADD);
    assert_token(unwrap_primary(infix.lhs), "3");
    assert_token(unwrap_primary(infix.rhs), "6");
}

fn void parse_infix_sub()
{
    Ast ast = parse(`
        10 - 4
    `);
    Infix* infix = unwrap_infix(unwrap_nth(ast.expressions, 0), SUB);
    assert_token(unwrap_primary(infix.lhs), "10");
    assert_token(unwrap_primary(infix.rhs), "4");
}

fn void parse_infix_mul()
{
    Ast ast = parse(`
        3 * 4
    `);
    Infix* infix = unwrap_infix(unwrap_nth(ast.expressions, 0), MUL);
    assert_token(unwrap_primary(infix.lhs), "3");
    assert_token(unwrap_primary(infix.rhs), "4");
}

fn void parse_infix_div()
{
    Ast ast = parse(`
        8 / 2
    `);
    Infix* infix = unwrap_infix(unwrap_nth(ast.expressions, 0), DIV);
    assert_token(unwrap_primary(infix.lhs), "8");
    assert_token(unwrap_primary(infix.rhs), "2");
}

// --- precedence ---
fn void parse_precedence_mul_over_add()
{
    // 1 + (2 * 3)
    Ast ast = parse(`
        1 + 2 * 3
    `);
    Infix* add = unwrap_infix(unwrap_nth(ast.expressions, 0), ADD);
    assert_token(unwrap_primary(add.lhs), "1");
    Infix* mul = unwrap_infix(add.rhs, MUL);
    assert_token(unwrap_primary(mul.lhs), "2");
    assert_token(unwrap_primary(mul.rhs), "3");
}

fn void parse_precedence_div_over_sub()
{
    // 6 - (2 / 3)
    Ast ast = parse(`
        6 - 2 / 3
    `);
    Infix* sub = unwrap_infix(unwrap_nth(ast.expressions, 0), SUB);
    assert_token(unwrap_primary(sub.lhs), "6");
    Infix* mul = unwrap_infix(sub.rhs, DIV);
    assert_token(unwrap_primary(mul.lhs), "2");
    assert_token(unwrap_primary(mul.rhs), "3");
}

fn void parse_precedence_pow_over_mul()
{
    // 2 * (3 ** 4)
    Ast ast = parse(`
        2 * 3 ** 4
    `);
    Infix* mul = unwrap_infix(unwrap_nth(ast.expressions, 0), MUL);
    assert_token(unwrap_primary(mul.lhs), "2");
    Infix* pow = unwrap_infix(mul.rhs, POW);
    assert_token(unwrap_primary(pow.lhs), "3");
    assert_token(unwrap_primary(pow.rhs), "4");
}

fn void parse_precedence_three_levels()
{
    // 1 + (2 * (3 ** 4))
    Ast ast = parse(`
        1 + 2 * 3 ** 4
    `);
    Infix* add = unwrap_infix(unwrap_nth(ast.expressions, 0), ADD);
    assert_token(unwrap_primary(add.lhs), "1");
    Infix* mul = unwrap_infix(add.rhs, MUL);
    assert_token(unwrap_primary(mul.lhs), "2");
    Infix* pow = unwrap_infix(mul.rhs, POW);
    assert_token(unwrap_primary(pow.lhs), "3");
    assert_token(unwrap_primary(pow.rhs), "4");
}

// --- associativity ---
fn void parse_left_assoc_add()
{
    // (1 + 2) + 3
    Ast ast = parse(`
        1 + 2 + 3
    `);
    Infix* outer = unwrap_infix(unwrap_nth(ast.expressions, 0), ADD);
    Infix* inner = unwrap_infix(outer.lhs, ADD);
    assert_token(unwrap_primary(inner.lhs), "1");
    assert_token(unwrap_primary(inner.rhs), "2");
    assert_token(unwrap_primary(outer.rhs), "3");
}

fn void parse_left_assoc_sub()
{
    // (9 - 3) - 2
    Ast ast = parse(`
        9 - 3 - 2
    `);
    Infix* outer = unwrap_infix(unwrap_nth(ast.expressions, 0), SUB);
    Infix* inner = unwrap_infix(outer.lhs, SUB);
    assert_token(unwrap_primary(inner.lhs), "9");
    assert_token(unwrap_primary(inner.rhs), "3");
    assert_token(unwrap_primary(outer.rhs), "2");
}

fn void parse_right_assoc_pow()
{
    // 2 ** (3 ** 2)
    Ast ast = parse(`
        2 ** 3 ** 2
    `);
    Infix* outer = unwrap_infix(unwrap_nth(ast.expressions, 0), POW);
    assert_token(unwrap_primary(outer.lhs), "2");
    Infix* inner = unwrap_infix(outer.rhs, POW);
    assert_token(unwrap_primary(inner.lhs), "3");
    assert_token(unwrap_primary(inner.rhs), "2");
}

// --- prefix ---
fn void parse_prefix_neg()
{
    Ast ast = parse(`
        -5
    `);
    Prefix* prefix = unwrap_prefix(unwrap_nth(ast.expressions, 0), NEG);
    assert_token(unwrap_primary(prefix.rhs), "5");
}

fn void parse_prefix_not()
{
    Ast ast = parse(`
        !67
    `);
    Prefix* prefix = unwrap_prefix(unwrap_nth(ast.expressions, 0), NOT);
    assert_token(unwrap_primary(prefix.rhs), "67");
}

fn void parse_prefix_neg_in_expr()
{
    // 1 + (-2)
    Ast ast = parse(`
        1 + -2
    `);
    Infix* add = unwrap_infix(unwrap_nth(ast.expressions, 0), ADD);
    assert_token(unwrap_primary(add.lhs), "1");
    Prefix* neg = unwrap_prefix(add.rhs, NEG);
    assert_token(unwrap_primary(neg.rhs), "2");
}

fn void parse_prefix_double_neg()
{
    // -(-4)
    Ast ast = parse(`
        --4
    `);
    Prefix* outer = unwrap_prefix(unwrap_nth(ast.expressions, 0), NEG);
    Prefix* inner = unwrap_prefix(outer.rhs, NEG);
    assert_token(unwrap_primary(inner.rhs), "4");
}

// --- postfix ---
fn void parse_postfix_async()
{
    Ast ast = parse(`
        echo &
    `);
    Postfix* post = unwrap_postfix(unwrap_nth(ast.expressions, 0), EXEC_ASYNC);
	Call* call = unwrap_call(post.lhs);
	assert_token(unwrap_primary(call.callee), "echo");
    assert(call.args.len() == 0);
}

fn void parse_postfix_loose_binding()
{
    // (1 + 2) &
    Ast ast = parse(`
        1 + 2 &
    `);
    Postfix* post = unwrap_postfix(unwrap_nth(ast.expressions, 0), EXEC_ASYNC);
    Infix* add = unwrap_infix(post.lhs, ADD);
    assert_token(unwrap_primary(add.lhs), "1");
    assert_token(unwrap_primary(add.rhs), "2");
}

// --- grouping ---
fn void parse_grouping_overrides_precedence()
{
    // ((1 + 2)) * 3
    Ast ast = parse(`
        (1 + 2) * 3
    `);
    Infix* mul = unwrap_infix(unwrap_nth(ast.expressions, 0), MUL);
    Infix* add = unwrap_infix(mul.lhs, ADD);
    assert_token(unwrap_primary(add.lhs), "1");
    assert_token(unwrap_primary(add.rhs), "2");
    assert_token(unwrap_primary(mul.rhs), "3");
}

fn void parse_grouping_nested()
{
    Ast ast = parse(`
        (1 + (2 + 3))
    `);
    Infix* add = unwrap_infix(unwrap_nth(ast.expressions, 0), ADD);
    assert_token(unwrap_primary(add.lhs), "1");
    Infix* mul = unwrap_infix(add.rhs, ADD);
    assert_token(unwrap_primary(mul.lhs), "2");
    assert_token(unwrap_primary(mul.rhs), "3");
}
