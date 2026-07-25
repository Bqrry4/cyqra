module cyqra::parser @test;
import cyqra::ast;

// --- list ---
fn void parse_empty_list()
{
    Ast ast = parse(`
        []
    `);
    LiteralList* list = unwrap_list(unwrap_literal(unwrap_nth(ast.expressions, 0)));
    assert(list.len() == 0);
}

fn void parse_list_single()
{
    Ast ast = parse(`
        [1]
    `);
    LiteralList* list = unwrap_list(unwrap_literal(unwrap_nth(ast.expressions, 0)));
    assert(list.len() == 1);
    assert_int(list.[0], 1);
}

fn void parse_list_multiple()
{
    Ast ast = parse(`
        [1, 2, 3]
    `);
    LiteralList* list = unwrap_list(unwrap_literal(unwrap_nth(ast.expressions, 0)));
    assert(list.len() == 3);
    assert_int(list.[0], 1);
    assert_int(list.[1], 2);
    assert_int(list.[2], 3);
}

fn void parse_list_trailing_comma()
{
    Ast ast = parse(`
        [1, 2, 3,]
    `);
    LiteralList* list = unwrap_list(unwrap_literal(unwrap_nth(ast.expressions, 0)));
    assert(list.len() == 3);
}

// fn void parse_list_expression_elements()
// {
//     Ast ast = parse(`
//         [1 + 2, 3 * 4]
//     `);
//     LiteralList* list = unwrap_list(unwrap_literal(unwrap_nth(ast.expressions, 0)));
//     assert(list.len() == 2);
//     Infix* add = unwrap_infix(list[0], ADD);
//     assert_token(unwrap_primary(add.lhs), "1");
//     assert_token(unwrap_primary(add.rhs), "2");
//     Infix* mul = unwrap_infix(list[1], MUL);
//     assert_token(unwrap_primary(mul.lhs), "3");
//     assert_token(unwrap_primary(mul.rhs), "4");
// }

// fn void parse_list_nested()
// {
//     Ast ast = parse(`
//         [[1, 2], [3, 4]]
//     `);
//     list* outer = unwrap_literal_list(unwrap_nth(ast.expressions, 0));
//     assert(outer.elements.len() == 2);
//     list* first = unwrap_literal_list(outer.elements[0]);
//     assert_token(unwrap_primary(first.elements[0]), "1");
//     assert_token(unwrap_primary(first.elements[1]), "2");
//     list* second = unwrap_literal_list(outer.elements[1]);
//     assert_token(unwrap_primary(second.elements[0]), "3");
//     assert_token(unwrap_primary(second.elements[1]), "4");
// }

// --- record ---
fn void parse_empty_record()
{
    Ast ast = parse(`
        {}
    `);
    LiteralRecord* rec = unwrap_record(unwrap_literal(unwrap_nth(ast.expressions, 0)));
    assert(rec.len() == 0);
}

// fn void parse_record_single_field()
// {
//     Ast ast = parse(`
//         { a: 1 }
//     `);
//     LiteralRecord* rec = unwrap_record(unwrap_literal(unwrap_nth(ast.expressions, 0)));
//     assert(rec.len() == 1);
//     assert_token(unwrap_primary(rec.[0].key), "a");
//     assert_int(unwrap_literal(rec.[0].value), 1);
// }

// fn void parse_record_multiple_fields()
// {
//     Ast ast = parse(`
//         { a: 1, b: 2, c: 3 }
//     `);
//     LiteralRecord* rec = unwrap_record(unwrap_nth(ast.expressions, 0));
//     assert(rec.fields.len() == 3);
//     assert_token(unwrap_primary(rec.fields[0].key), "a");
//     assert_token(unwrap_primary(rec.fields[0].value), "1");
//     assert_token(unwrap_primary(rec.fields[1].key), "b");
//     assert_token(unwrap_primary(rec.fields[1].value), "2");
//     assert_token(unwrap_primary(rec.fields[2].key), "c");
//     assert_token(unwrap_primary(rec.fields[2].value), "3");
// }
// fn void parse_record_multiple_fields_new_line_separated()
// {
//     Ast ast = parse(`
//         {
//             a: 1,
//             b: 2
//             c: 3
//          }
//     `);
//     LiteralRecord* rec = unwrap_record(unwrap_nth(ast.expressions, 0));
//     assert(rec.fields.len() == 3);
//     assert_token(unwrap_primary(rec.fields[0].key), "a");
//     assert_token(unwrap_primary(rec.fields[0].value), "1");
//     assert_token(unwrap_primary(rec.fields[1].key), "b");
//     assert_token(unwrap_primary(rec.fields[1].value), "2");
//     assert_token(unwrap_primary(rec.fields[2].key), "c");
//     assert_token(unwrap_primary(rec.fields[2].value), "3");
// }
// fn void parse_record_trailing_comma()
// {
//     Ast ast = parse(`
//         { a: 1, b: 2, }
//     `);
//     LiteralRecord* rec = unwrap_record(unwrap_nth(ast.expressions, 0));
//     assert(rec.fields.len() == 2);
// }

// fn void parse_record_expression_value()
// {
//     Ast ast = parse(`
//         { a: 1 + 2 }
//     `);
//     LiteralRecord* rec = unwrap_record(unwrap_nth(ast.expressions, 0));
//     assert(rec.fields.len() == 1);
//     Infix* add = unwrap_infix(rec.fields[0].value, ADD);
//     assert_token(unwrap_primary(add.lhs), "1");
//     assert_token(unwrap_primary(add.rhs), "2");
// }

// fn void parse_record_string_key()
// {
//     Ast ast = parse(`
//         { "name": 1 }
//     `);
//     LiteralRecord* rec = unwrap_record(unwrap_nth(ast.expressions, 0));
//     assert(rec.fields.len() == 1);
//     // string key is a StringLit node
//     StringLit* key = unwrap_string(rec.fields[0].key);
//     assert(key.parts.len() == 1);
//     assert(key.parts[0].text == "name");
// }

// fn void parse_record_nested()
// {
//     Ast ast = parse(`
//         { a: { b: 1 } }
//     `);
//     LiteralRecord* outer = unwrap_record(unwrap_nth(ast.expressions, 0));
//     assert(outer.fields.len() == 1);
//     LiteralRecord* inner = unwrap_record(outer.fields[0].value);
//     assert(inner.fields.len() == 1);
//     assert_token(unwrap_primary(inner.fields[0].key), "b");
//     assert_token(unwrap_primary(inner.fields[0].value), "1");
// }

// fn void parse_record_list_value()
// {
//     Ast ast = parse(`
//         { a: [1, 2, 3] }
//     `);
//     LiteralRecord* rec = unwrap_record(unwrap_nth(ast.expressions, 0));
//     LiteralList* list = unwrap_literal_list(rec.fields[0].value);
//     assert(list.len() == 3);
// }

// fn void parse_list_of_records()
// {
//     Ast ast = parse(`
//         [{ a: 1 }, { a: 2 }]
//     `);
//     LiteralList* list = unwrap_literal_list(unwrap_nth(ast.expressions, 0));
//     assert(list.len() == 2);
//     LiteralRecord* first = unwrap_record(list[0]);
//     assert_token(unwrap_primary(first.fields[0].value), "1");
//     LiteralRecord* second = unwrap_record(list[1]);
//     assert_token(unwrap_primary(second.fields[0].value), "2");
// }

// // --- index ---
// fn void parse_list_index()
// {
//     Ast ast = parse(`
//         let a = []
//         a[0]
//     `);
//     Index* idx = unwrap_index(unwrap_nth(ast.expressions, 1));
//     assert_var(p.vars, idx.object, "a");
//     assert_token(unwrap_primary(idx.index), "0");
// }

// fn void parse_list_index_expr()
// {
//     Ast ast = parse(`
//         let a = []
//         a[1 + 2]
//     `);
//     Index* idx = unwrap_index(unwrap_nth(ast.expressions, 1));
//     assert_var(p.vars, idx.object, "a");
//     Infix* add = unwrap_infix(idx.index, ADD);
//     assert_token(unwrap_primary(add.lhs), "1");
//     assert_token(unwrap_primary(add.rhs), "2");
// }

// fn void parse_list_chained_index()
// {
//     // (a[0])[1]
//     Ast ast = parse(`
//         let a = []
//         a[0][1]
//     `);
//     Index* outer = unwrap_index(unwrap_nth(ast.expressions, 1));
//     Index* inner = unwrap_index(outer.object);
//     assert_var(p.vars, inner.object, "a");
//     assert_token(unwrap_primary(inner.index), "0");
//     assert_token(unwrap_primary(outer.index), "1");
// }

