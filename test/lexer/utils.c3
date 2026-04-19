module cyqra::lexer @test;

macro lexer_analyze(String content)
{
	Lexer lex = lexer::new(tmem);
	return lex.analyze(content);
}

macro bool match_tokens(tokens, ...)
{
	bool matches = true;
	$for var $i = 0; $i < $vacount; $i++:
        matches = matches && tokens[$i].kind == $vaconst[$i];
    $endfor
	return matches;
}
