module cyqra::parser @test;

// --- array ---
fn void parse_empty_array()
{
    Ast ast = parse(`
        []
    `);
    Array* arr = unwrap_array(unwrap_nth(ast.expressions, 0));
    assert(arr.elements.len() == 0);
}

fn void parse_array_single()
{
    Ast ast = parse(`
        [1]
    `);
    Array* arr = unwrap_array(unwrap_nth(ast.expressions, 0));
    assert(arr.elements.len() == 1);
    assert_token(unwrap_primary(arr.elements[0]), "1");
}

fn void parse_array_multiple()
{
    Ast ast = parse(`
        [1, 2, 3]
    `);
    Array* arr = unwrap_array(unwrap_nth(ast.expressions, 0));
    assert(arr.elements.len() == 3);
    assert_token(unwrap_primary(arr.elements[0]), "1");
    assert_token(unwrap_primary(arr.elements[1]), "2");
    assert_token(unwrap_primary(arr.elements[2]), "3");
}

fn void parse_array_trailing_comma()
{
    Ast ast = parse(`
        [1, 2, 3,]
    `);
    Array* arr = unwrap_array(unwrap_nth(ast.expressions, 0));
    assert(arr.elements.len() == 3);
}

fn void parse_array_expression_elements()
{
    Ast ast = parse(`
        [1 + 2, 3 * 4]
    `);
    Array* arr = unwrap_array(unwrap_nth(ast.expressions, 0));
    assert(arr.elements.len() == 2);
    Infix* add = unwrap_infix(arr.elements[0], ADD);
    assert_token(unwrap_primary(add.lhs), "1");
    assert_token(unwrap_primary(add.rhs), "2");
    Infix* mul = unwrap_infix(arr.elements[1], MUL);
    assert_token(unwrap_primary(mul.lhs), "3");
    assert_token(unwrap_primary(mul.rhs), "4");
}

fn void parse_array_nested()
{
    Ast ast = parse(`
        [[1, 2], [3, 4]]
    `);
    Array* outer = unwrap_array(unwrap_nth(ast.expressions, 0));
    assert(outer.elements.len() == 2);
    Array* first = unwrap_array(outer.elements[0]);
    assert_token(unwrap_primary(first.elements[0]), "1");
    assert_token(unwrap_primary(first.elements[1]), "2");
    Array* second = unwrap_array(outer.elements[1]);
    assert_token(unwrap_primary(second.elements[0]), "3");
    assert_token(unwrap_primary(second.elements[1]), "4");
}

// --- record ---
fn void parse_empty_record()
{
    Ast ast = parse(`
        {}
    `);
    Record* rec = unwrap_record(unwrap_nth(ast.expressions, 0));
    assert(rec.fields.len() == 0);
}

fn void parse_record_single_field()
{
    Ast ast = parse(`
        { a: 1 }
    `);
    Record* rec = unwrap_record(unwrap_nth(ast.expressions, 0));
    assert(rec.fields.len() == 1);
    assert_token(unwrap_primary(rec.fields[0].key), "a");
    assert_token(unwrap_primary(rec.fields[0].value), "1");
}

fn void parse_record_multiple_fields()
{
    Ast ast = parse(`
        { a: 1, b: 2, c: 3 }
    `);
    Record* rec = unwrap_record(unwrap_nth(ast.expressions, 0));
    assert(rec.fields.len() == 3);
    assert_token(unwrap_primary(rec.fields[0].key), "a");
    assert_token(unwrap_primary(rec.fields[0].value), "1");
    assert_token(unwrap_primary(rec.fields[1].key), "b");
    assert_token(unwrap_primary(rec.fields[1].value), "2");
    assert_token(unwrap_primary(rec.fields[2].key), "c");
    assert_token(unwrap_primary(rec.fields[2].value), "3");
}
fn void parse_record_multiple_fields_new_line_separated()
{
    Ast ast = parse(`
        {
            a: 1,
            b: 2
            c: 3
         }
    `);
    Record* rec = unwrap_record(unwrap_nth(ast.expressions, 0));
    assert(rec.fields.len() == 3);
    assert_token(unwrap_primary(rec.fields[0].key), "a");
    assert_token(unwrap_primary(rec.fields[0].value), "1");
    assert_token(unwrap_primary(rec.fields[1].key), "b");
    assert_token(unwrap_primary(rec.fields[1].value), "2");
    assert_token(unwrap_primary(rec.fields[2].key), "c");
    assert_token(unwrap_primary(rec.fields[2].value), "3");
}
fn void parse_record_trailing_comma()
{
    Ast ast = parse(`
        { a: 1, b: 2, }
    `);
    Record* rec = unwrap_record(unwrap_nth(ast.expressions, 0));
    assert(rec.fields.len() == 2);
}

fn void parse_record_expression_value()
{
    Ast ast = parse(`
        { a: 1 + 2 }
    `);
    Record* rec = unwrap_record(unwrap_nth(ast.expressions, 0));
    assert(rec.fields.len() == 1);
    Infix* add = unwrap_infix(rec.fields[0].value, ADD);
    assert_token(unwrap_primary(add.lhs), "1");
    assert_token(unwrap_primary(add.rhs), "2");
}

fn void parse_record_string_key()
{
    Ast ast = parse(`
        { "name": 1 }
    `);
    Record* rec = unwrap_record(unwrap_nth(ast.expressions, 0));
    assert(rec.fields.len() == 1);
    // string key is a StringLit node
    StringLit* key = unwrap_string(rec.fields[0].key);
    assert(key.parts.len() == 1);
    assert(key.parts[0].text == "name");
}

fn void parse_record_nested()
{
    Ast ast = parse(`
        { a: { b: 1 } }
    `);
    Record* outer = unwrap_record(unwrap_nth(ast.expressions, 0));
    assert(outer.fields.len() == 1);
    Record* inner = unwrap_record(outer.fields[0].value);
    assert(inner.fields.len() == 1);
    assert_token(unwrap_primary(inner.fields[0].key), "b");
    assert_token(unwrap_primary(inner.fields[0].value), "1");
}

fn void parse_record_array_value()
{
    Ast ast = parse(`
        { a: [1, 2, 3] }
    `);
    Record* rec = unwrap_record(unwrap_nth(ast.expressions, 0));
    Array* arr = unwrap_array(rec.fields[0].value);
    assert(arr.elements.len() == 3);
}

fn void parse_array_of_records()
{
    Ast ast = parse(`
        [{ a: 1 }, { a: 2 }]
    `);
    Array* arr = unwrap_array(unwrap_nth(ast.expressions, 0));
    assert(arr.elements.len() == 2);
    Record* first = unwrap_record(arr.elements[0]);
    assert_token(unwrap_primary(first.fields[0].value), "1");
    Record* second = unwrap_record(arr.elements[1]);
    assert_token(unwrap_primary(second.fields[0].value), "2");
}

// --- index ---
fn void parse_array_index()
{
    Ast ast = parse(`
        a[0]
    `);
    Index* idx = unwrap_index(unwrap_nth(ast.expressions, 0));
    assert_token(unwrap_primary(idx.object), "a");
    assert_token(unwrap_primary(idx.index), "0");
}

fn void parse_array_index_expr()
{
    Ast ast = parse(`
        a[1 + 2]
    `);
    Index* idx = unwrap_index(unwrap_nth(ast.expressions, 0));
    assert_token(unwrap_primary(idx.object), "a");
    Infix* add = unwrap_infix(idx.index, ADD);
    assert_token(unwrap_primary(add.lhs), "1");
    assert_token(unwrap_primary(add.rhs), "2");
}

fn void parse_array_chained_index()
{
    // (a[0])[1]
    Ast ast = parse(`
        a[0][1]
    `);
    Index* outer = unwrap_index(unwrap_nth(ast.expressions, 0));
    Index* inner = unwrap_index(outer.object);
    assert_token(unwrap_primary(inner.object), "a");
    assert_token(unwrap_primary(inner.index), "0");
    assert_token(unwrap_primary(outer.index), "1");
}

