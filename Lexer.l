%option lex = "nextToken"
%option lexer = "Lexer"
%option bison-cc
%option bison-cc-parser = "Parser"
%option bison-cc-namespace = "ExprP"

%top{
#include "Parser.hpp"
#include <string>
#include <iostream>
}



%%
[0-9]+  { yylval.emplace<int>(std::stoi(text())); return ExprP::Parser::token::CONST_NUMBER; }
"+"      { return ExprP::Parser::token::OP_PLUS; }
"*"      { return ExprP::Parser::token::OP_MULT; }
"("      { return ExprP::Parser::token::OPEN_PAR; }
")"      { return ExprP::Parser::token::CLOSE_PAR; }
[a-zA-Z_][a-zA-Z0-9_]* { yylval.emplace<std::string>(text()); return ExprP::Parser::token::IDENTIFIER; }

[ \t\r\n] /* no action: ignore all white space */
.       { throw std::runtime_error("Unexpected character: " + std::string(text())); }
%%
