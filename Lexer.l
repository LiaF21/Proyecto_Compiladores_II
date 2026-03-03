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

"//".*  

"int"    { return ExprP::Parser::token::INT; }
"void"   { return ExprP::Parser::token::VOID; }
"if"     { return ExprP::Parser::token::IF; }
"else"   { return ExprP::Parser::token::ELSE; }
"while"  { return ExprP::Parser::token::WHILE; }
"print"  { return ExprP::Parser::token::PRINT; }
"def"    { return ExprP::Parser::token::DEF; }
"return" { return ExprP::Parser::token::RETURN; }
"ref"    { return ExprP::Parser::token::REF; }
[a-zA-Z_][a-zA-Z0-9_]* { 
    yylval.emplace<std::string>(text()); 
    return ExprP::Parser::token::IDENTIFIER; 
}

[0-9]+  { yylval.emplace<int>(std::stoi(text())); return ExprP::Parser::token::CONST_NUMBER; }
"=="     { return ExprP::Parser::token::EQ; }
"!="     { return ExprP::Parser::token::NEQ; }
"<="     { return ExprP::Parser::token::LTE; }
">="     { return ExprP::Parser::token::GTE; }
"&&"     { return ExprP::Parser::token::AND; }
"||"     { return ExprP::Parser::token::OR; }

"+"      { return ExprP::Parser::token::OP_PLUS; }
"-"      { return ExprP::Parser::token::OP_MINUS; }
"*"      { return ExprP::Parser::token::OP_MULT; }
"/"      { return ExprP::Parser::token::OP_DIV; }
"%"      { return ExprP::Parser::token::OP_MOD; }

"<"      { return ExprP::Parser::token::LT; }
">"      { return ExprP::Parser::token::GT; }
"!"      { return ExprP::Parser::token::NOT; }
"="      { return ExprP::Parser::token::ASSIGN; }

"("      { return ExprP::Parser::token::OPEN_PAR; }
")"      { return ExprP::Parser::token::CLOSE_PAR; }
";"      { return ExprP::Parser::token::SEMICOLON; }
","      { return ExprP::Parser::token::COMMA; }
"{"      { return ExprP::Parser::token::OPEN_BRACE; }
"}"      { return ExprP::Parser::token::CLOSE_BRACE; }
[ \t\r\n] /* no action: ignore all white space */
.       { throw std::runtime_error("Caracter inesperado: " + std::string(text())); }
%%
