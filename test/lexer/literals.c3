module cyqra::lexer @test;
import std::collections::list;
import std::io;

fn void lex_int() => @pool()
{
	List{ Token } tokens = lexer_analyze("4");
	assert(tokens[0].kind == INTEGER);
}

fn void lex_float() => @pool()
{
	List{ Token } tokens = lexer_analyze("3.66");
	assert(tokens[0].kind == FLOAT);
}

fn void lex_negative_int() => @pool()
{
	List{ Token } tokens = lexer_analyze("-3");
	assert(tokens[0].kind == MINUS);
	assert(tokens[1].kind == INTEGER);
}

fn void lex_number_trailing_dot() => @pool()
{
	List{ Token } tokens = lexer_analyze("1.");
	assert(tokens[0].kind == FLOAT);
}






