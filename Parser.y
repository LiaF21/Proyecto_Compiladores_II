%language "C++"
%require "3.2"
%define api.value.type variant
%define api.token.constructor

// Keywords
%token INT "int"
%token VOID "void"
%token IF "if"
%token ELSE "else"
%token WHILE "while"
%token PRINT "print"
%token DEF "def"
%token RETURN "return"
%token REF "ref"

// Operators
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
%token ARROW "'->'"

// Punctuation
%token OPEN_PAR "'('"
%token CLOSE_PAR "')'"
%token SEMICOLON "';'"
%token COMMA "','"
%token OPEN_BRACE "'{'"
%token CLOSE_BRACE "'}'"
%token OSQR_BRACE "'['"
%token CSQR_BRACE "']'"

// Literals and Identifiers
%token <long> CONST_NUMBER "num"
%token <std::string> IDENTIFIER "identifier"

%define api.namespace {ExprP}
%define api.parser.class {Parser}
%parse-param {Lexer& lexer} 
%parse-param {AstNode*& root}
%lex-param {Lexer& lexer}
%define parse.error verbose


%nterm <AstNode*> program
%nterm <Nodes*> declaration_list
%nterm <AstNode*> declaration
%nterm <AstNode*> varDecl varDeclInit 
%nterm <AstNode*> funcDecl
%nterm <AstNode*> returnType
%nterm <Nodes*> paramListOpt paramList
%nterm <AstNode*> param
%nterm <bool*> paramRefOpt
%nterm <Nodes*> statement_list
%nterm <AstNode*> statement matchedStmt unmatchedStmt
%nterm <AstNode*> assignment whileStmt printStmt returnStmt exprStmt block
%nterm <AstNode*> expression
%nterm <AstNode*> logicalOr
%nterm <AstNode*> logicalAnd
%nterm <AstNode*> equality
%nterm <AstNode*> comparison
%nterm <AstNode*> term
%nterm <AstNode*> factor
%nterm <AstNode*> unary
%nterm <AstNode*> primary
%nterm <AstNode*> funcCall
%nterm <Nodes*> argListOpt argList

%code requires{
    #include <string>
    #include <vector>
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

program: declaration_list { 
    Nodes declarations;
    if ($1) {
        declarations = *$1;
        delete $1;
    }
    root = static_cast<AstNode*>(new Program(declarations));
}
;

declaration_list: %empty { 
    $$ = new Nodes();
}
| declaration_list declaration { 
    $$ = $1;
    if ($2) {
        $$->push_back($2);
    }
}
;

declaration: varDecl { 
    $$ = static_cast<AstNode*>($1);
}  
| funcDecl { 
    $$ = static_cast<AstNode*>($1);
}
;

varDecl: INT IDENTIFIER varDeclInit SEMICOLON { 
    if ($3) {
        $$ = static_cast<AstNode*>(new VarDeclStmt($2, $3));
    } else {
        $$ = static_cast<AstNode*>(new VarDeclStmt($2, nullptr));
    }
}
;

varDeclInit: ASSIGN expression { 
    $$ = static_cast<AstNode*>($2);
}
| %empty { 
    $$ = nullptr;
}
;


funcDecl: DEF IDENTIFIER OPEN_PAR paramListOpt CLOSE_PAR ARROW returnType block { 
    Nodes params;
    if ($4) {
        params = *$4;
        delete $4;
    }
    Nodes body;
    auto blockStmt = dynamic_cast<BlockStmt*>($8);
    if (blockStmt) {
        body = blockStmt->stmts;
    }
    $$ = static_cast<AstNode*>(new FuncDefinition($2, params, $7, body));
}
;

returnType: INT { 
    $$ = static_cast<AstNode*>(new IntType());
}
| VOID { 
    $$ = static_cast<AstNode*>(new VoidType());
}
;

paramListOpt: paramList { 
    $$ = $1; 
}
| %empty { 
    $$ = nullptr; 
}
;

paramList: param { 
    $$ = new Nodes();
    if ($1) $$->push_back($1);
}
| paramList COMMA param { 
    $$ = $1;
    if ($3) $$->push_back($3);
}
;

param: INT paramRefOpt IDENTIFIER { 
    if ($2 && *$2) {
        $$ = static_cast<AstNode*>(new RefParam($3));
    } else {
        $$ = static_cast<AstNode*>(new Param($3));
    }
}
;

paramRefOpt: REF { 
    $$ = new bool(true); 
}
| %empty { 
    $$ = new bool(false); 
}
;

statement_list: %empty { 
    $$ = new Nodes(); 
}
| statement_list statement { 
    $$ = $1;
    if ($2) $$->push_back($2);
}
;

statement: matchedStmt { 
    $$ = static_cast<AstNode*>($1);
}
| unmatchedStmt { 
    $$ = static_cast<AstNode*>($1);
}
;

matchedStmt: varDecl { 
    $$ = static_cast<AstNode*>($1);
}
| assignment { 
    $$ = static_cast<AstNode*>($1);
}
| whileStmt { 
    $$ = static_cast<AstNode*>($1);
}
| printStmt { 
    $$ = static_cast<AstNode*>($1);
}
| returnStmt { 
    $$ = static_cast<AstNode*>($1);
}
| exprStmt { 
    $$ = static_cast<AstNode*>($1);
}
| block { 
    $$ = static_cast<AstNode*>($1);
}
| IF OPEN_PAR expression CLOSE_PAR matchedStmt ELSE matchedStmt { 
    $$ = static_cast<AstNode*>(new IfStmt($3, $5, $7));
}
;

unmatchedStmt: IF OPEN_PAR expression CLOSE_PAR statement { 
    $$ = static_cast<AstNode*>(new IfStmt($3, $5, nullptr));
}
| IF OPEN_PAR expression CLOSE_PAR matchedStmt ELSE unmatchedStmt { 
    $$ = static_cast<AstNode*>(new IfStmt($3, $5, $7));
}
;

assignment: IDENTIFIER ASSIGN expression SEMICOLON { 
    $$ = static_cast<AstNode*>(new AssignStmt($1, $3));
}
;

whileStmt: WHILE OPEN_PAR expression CLOSE_PAR matchedStmt { 
    $$ = static_cast<AstNode*>(new WhileStmt($3, $5));
}
;

printStmt: PRINT OPEN_PAR expression CLOSE_PAR SEMICOLON { 
    Nodes content;
    if ($3) {
        content.push_back($3);
    }
    $$ = static_cast<AstNode*>(new PrintStmt(content));
}
;

returnStmt: RETURN expression SEMICOLON { 
    $$ = static_cast<AstNode*>(new ReturnStmt($2));
}
| RETURN SEMICOLON { 
    $$ = static_cast<AstNode*>(new ReturnStmt(nullptr));
}
;

exprStmt: funcCall SEMICOLON { 
    $$ = static_cast<AstNode*>($1);
}
;

block: OPEN_BRACE statement_list CLOSE_BRACE { 
    Nodes stmts;
    if ($2) {
        stmts = *$2;
        delete $2;
    }
    $$ = static_cast<AstNode*>(new BlockStmt(stmts));
}
;

expression: logicalOr { 
    $$ = static_cast<AstNode*>($1);
}
;

logicalOr: logicalAnd { 
    $$ = static_cast<AstNode*>($1);
}
| logicalOr OR logicalAnd { 
    $$ = static_cast<AstNode*>(new OrExpr($1, $3));
}
;

logicalAnd: equality { 
    $$ = static_cast<AstNode*>($1);
}
| logicalAnd AND equality { 
    $$ = static_cast<AstNode*>(new AndExpr($1, $3));
}
;

equality: comparison { 
    $$ = static_cast<AstNode*>($1);
}
| equality EQ comparison { 
    $$ = static_cast<AstNode*>(new EqualExpr($1, $3));
}
| equality NEQ comparison { 
    $$ = static_cast<AstNode*>(new NotEqualExpr($1, $3));
}
;

comparison: term { 
    $$ = static_cast<AstNode*>($1);
}
| comparison LT term { 
    $$ = static_cast<AstNode*>(new LtExpr($1, $3));
}
| comparison GT term { 
    $$ = static_cast<AstNode*>(new GtExpr($1, $3));
}
| comparison LTE term { 
    $$ = static_cast<AstNode*>(new LteExpr($1, $3));
}
| comparison GTE term { 
    $$ = static_cast<AstNode*>(new GteExpr($1, $3));
}
;

term: factor { 
    $$ = static_cast<AstNode*>($1);
}
| term OP_PLUS factor { 
    $$ = static_cast<AstNode*>(new AddExpr($1, $3));
}
| term OP_MINUS factor { 
    $$ = static_cast<AstNode*>(new SubExpr($1, $3));
}
;

factor: unary { 
    $$ = static_cast<AstNode*>($1);
}
| factor OP_MULT unary { 
    $$ = static_cast<AstNode*>(new MulExpr($1, $3));
}
| factor OP_DIV unary { 
    $$ = static_cast<AstNode*>(new DivExpr($1, $3));
}
| factor OP_MOD unary { 
    $$ = static_cast<AstNode*>(new ModExpr($1, $3));
}
;

unary: NOT unary { 
    $$ = static_cast<AstNode*>(new NotExpr($2));
}
| OP_MINUS unary { 
    $$ = static_cast<AstNode*>(new NegExpr($2));
}
| primary { 
    $$ = static_cast<AstNode*>($1);
}
;

primary: CONST_NUMBER { 
    $$ = static_cast<AstNode*>(new NumberExpr($1));
}
| IDENTIFIER { 
    $$ = static_cast<AstNode*>(new IdentifierExpr($1));
}
| funcCall { 
    $$ = static_cast<AstNode*>($1);
}
| OPEN_PAR expression CLOSE_PAR { 
    $$ = static_cast<AstNode*>($2);
}
;

funcCall: IDENTIFIER OPEN_PAR argListOpt CLOSE_PAR { 
    Nodes arguments;
    if ($3) {
        arguments = *$3;
        delete $3;
    }
    $$ = static_cast<AstNode*>(new CallExpr($1, arguments));
}
;

argListOpt: argList { 
    $$ = $1;
}
| %empty { 
    $$ = nullptr;
}
;

argList: expression { 
    $$ = new Nodes();
    if ($1) $$->push_back($1);
}
| argList COMMA expression { 
    $$ = $1;
    if ($3) $$->push_back($3);
}
;

%%