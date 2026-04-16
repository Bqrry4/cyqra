module cyqra::lexer @test;
import std::collections::list;
import std::io;

macro bool match_tokens(tokens, ...)
{
	bool matches = true;
	$for var $i = 0; $i < $vacount; $i++:
        matches = matches && tokens[$i].kind == $vaconst[$i];
    $endfor
	return matches;
}


fn void lex_string() => @pool()
{
	List{ Token } tokens = lexer_analyze("\"Hello\"");
	assert(match_tokens(tokens,
		D_QUOTES, STRING_PART, D_QUOTES	
	));
}

fn void lex_string_iterp_ident() => @pool()
{
	List{ Token } tokens = lexer_analyze("\"Hello $world\"");
	assert(match_tokens(tokens,
		D_QUOTES, STRING_PART, INTERP_IDENT, IDENTIFIER, D_QUOTES	
	));
}
