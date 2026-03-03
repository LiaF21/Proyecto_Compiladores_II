%language "C++"
%require "3.2"
%define api.value.type variant
%define api.token.constructor


%token INT "int"
%token VOID "void"
%token IF "if"
%token ELSE "else"
%token WHILE "while"
%token PRINT "print"
%token DEF "def"
%token RETURN "return"
%token REF "ref"


%token OP_PLUS "'+'"
%token OP_MINUS "'-'"
%token OP_MULT "'*'"
%token OP_DIV "'/'"
%token OP_MOD "'%'"
%token EQ "'=='"
%token NEQ "'!='"
%token LT "'<'"
%token GT "'>'"
%token LTE "'<='"
%token GTE "'>='"

%token AND "'&&'"
%token OR "'||'"
%token NOT "'!'"
%token ASSIGN "'='"
%token OPEN_PAR "'('"
%token CLOSE_PAR "')'"
%token SEMICOLON "';'"
%token COMMA "','"
%token OPEN_BRACE "'{'"
%token CLOSE_BRACE "'}'"

%token <int> CONST_NUMBER "num"
%token <std::string> IDENTIFIER "identifier"
%define api.namespace {ExprP}
%define api.parser.class {Parser}
%parse-param {Lexer& lexer} {const std::unordered_map<std::string, int>& variables}
%lex-param {Lexer& lexer}
%define parse.error verbose

%nterm <AstNode*> input
%nterm <Expr*> expr term factor

%code requires{
    #include <string>
    #include <unordered_map>
    #include "tree.hpp"
    class Lexer;
}

%code{
    #include "Lexer.hpp"
    #include <iostream>
    using namespace ExprP;
    
    namespace ExprP
    {
        void Parser::error(const std::string& msg){
            throw std::runtime_error(msg);
        }
    }
    
    ExprP::Parser::symbol_type yylex(Lexer& lexer){
        ExprP::Parser::semantic_type yylval;
        int token = lexer.nextToken(yylval);
        
        switch(token) {
            case ExprP::Parser::token::CONST_NUMBER:
                return ExprP::Parser::symbol_type(token, yylval.as<int>());
            case ExprP::Parser::token::IDENTIFIER:
                return ExprP::Parser::symbol_type(token, std::move(yylval.as<std::string>()));
            default:
                return ExprP::Parser::symbol_type(token);
        }
    }
}

%%

input: expr {$$ = $1; }
    ;

expr: expr OP_PLUS term { $$ = new AddExpr($1, $3); }
    | term { $$ = $1; }
    ;

term: term OP_MULT factor { $$ = new MultExpr($1, $3); }
    | factor { $$ = $1; }
    ;

factor: OPEN_PAR expr CLOSE_PAR { $$ = $2; }
      | CONST_NUMBER { 
          $$ = new NumberExpr($1);
        }
      | IDENTIFIER { 
          $$ = new IdentifierExpr($1);
        }
    ;

%%