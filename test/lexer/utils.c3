module cyqra::lexer @test;

macro lexer_analyze(String content)
{
	Lexer lex = lexer::new(tmem);
	return lex.analyze(content);
}

macro bool match_tokens(tokens, ...)
{
	bool matches = true;
	$for var $i = 0; $i < $vaarg.len; $i++:
        matches = matches && tokens[$i].kind == $vaarg[$i];
    $endfor
	return matches;
}
