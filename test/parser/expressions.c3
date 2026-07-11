module cyqra::parser @test;
import std::io;
import cyqra::ast;

// --- literals ---
fn void parse_int()
{
	Ast ast = parse(`
		1
	`);
	assert_int(
		unwrap_nth(ast.expressions, 0),
		1
	);
}
fn void parse_float()
{
	Ast ast = parse(`
		3.6
	`);
	assert_float(
		unwrap_nth(ast.expressions, 0),
		3.6
	);
}

// --- fseq ---
fn void parse_fseq_infix()
{
	Ast ast = parse(`
		1 + 2
	`);
	FlatSequence* fseq = unwrap_fseq(unwrap_nth(ast.expressions, 0));
	assert(fseq.len() == 3);
	assert_int(fseq.[0], 1);
	assert_op(fseq.[1], Operator.ADD);
	assert_int(fseq.[2], 2);
}

fn void parse_fseq_mixed()
{
	Ast ast = parse(`
		!a() + 2 * -3 &
	`);
	FlatSequence* fseq = unwrap_fseq(unwrap_nth(ast.expressions, 0));
	assert(fseq.len() == 8);
	assert_op(fseq.[0], NOT);
	assert_ident(unwrap_call(fseq.[1]).callee, "a");
	assert_op(fseq.[2], ADD);
	assert_int(fseq.[3], 2);
	assert_op(fseq.[4], MUL);
	assert_op(fseq.[5], NEG);
	assert_int(fseq.[6], 3);
	assert_op(fseq.[7], EXEC_ASYNC);
}

// --- pipelines ---
fn void parse_pipeline()
{
    Ast ast = parse(`
        a | b | c
    `);
    Pipeline* ppln = unwrap_pipeline(ast.expressions[0]);
    assert(ppln.links.len() == 2);

	assert_ambiguous_ident(ppln.links[0].expr, "a");
    assert(ppln.links[0].mode == OUT);

	assert_ambiguous_ident(ppln.links[1].expr, "b");
    assert(ppln.links[1].mode == OUT);
	// 'c' doesn't continue with a space
	assert_ident(ppln.tail, "c");
}

fn void parse_pipeline_mixed()
{
    Ast ast = parse(`
        a | b |& c !| d
    `);
    Pipeline* ppln = unwrap_pipeline(ast.expressions[0]);
	assert(ppln.links.len() == 3);

	assert_ambiguous_ident(ppln.links[0].expr, "a");
    assert(ppln.links[0].mode == OUT);

	assert_ambiguous_ident(ppln.links[1].expr, "b");
    assert(ppln.links[1].mode == OUT_ERR);
	
	assert_ambiguous_ident(ppln.links[2].expr, "c");
    assert(ppln.links[2].mode == ERR);

	assert_ident(ppln.tail, "d");
}

