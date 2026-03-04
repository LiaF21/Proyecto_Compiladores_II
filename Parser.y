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
%nterm <std::string> returnType
%nterm <Nodes*> paramListOpt paramList
%nterm <AstNode*> param paramRefOpt
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
    Program* prog = new Program();
    if ($1) {
        prog->declarations = *$1;
        delete $1;
    }
    root = static_cast<AstNode*>(prog);
}
;

declaration_list: declaration declaration_list { 
    if ($2) {
        $$ = $2;
    } else {
        $$ = new Nodes();
    }
    if ($1) {
        $$->insert($$->begin(), $1);
    }
}
| %empty { 
    $$ = new Nodes(); 
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
    AstNode* stmt = static_cast<AstNode*>(new DeclStmt());
    dynamic_cast<DeclStmt*>(stmt)->name = $2;
    if ($3) {
        AstNode* assignStmt = static_cast<AstNode*>(new AssignStmt());
        dynamic_cast<AssignStmt*>(assignStmt)->name = $2;
        dynamic_cast<AssignStmt*>(assignStmt)->value = $3;
        $$ = assignStmt;
    } else {
        $$ = stmt;
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
    AstNode* func = static_cast<AstNode*>(new FuncDefinition());
    dynamic_cast<FuncDefinition*>(func)->name = $2;
    if ($4) {
        dynamic_cast<FuncDefinition*>(func)->params = *$4;
        delete $4;
    }
    auto blockStmt = dynamic_cast<BlockStmt*>($8);
    if (blockStmt) {
        dynamic_cast<FuncDefinition*>(func)->body = blockStmt->stmts;
    }
    $$ = func;
}
;

returnType: INT { 
    $$ = "int";
}
| VOID { 
    $$ = "void";
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
    AstNode* id = static_cast<AstNode*>(new IdentifierExpr());
    dynamic_cast<IdentifierExpr*>(id)->name = $3;
    $$ = id;
}
;

paramRefOpt: REF { 
    $$ = nullptr; 
}
| %empty { 
    $$ = nullptr; 
}
;

statement_list: statement { 
    $$ = new Nodes();
    if ($1) $$->push_back($1);
}
| statement statement_list { 
    $$ = $2;
    if ($1) $$->insert($$->begin(), $1);
}
| %empty { 
    $$ = new Nodes(); 
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
    $$ = static_cast<AstNode*>($5);
}
;

unmatchedStmt: IF OPEN_PAR expression CLOSE_PAR statement { 
    $$ = static_cast<AstNode*>($5);
}
| IF OPEN_PAR expression CLOSE_PAR matchedStmt ELSE unmatchedStmt { 
    $$ = static_cast<AstNode*>($5);
}
;

assignment: IDENTIFIER ASSIGN expression SEMICOLON { 
    AstNode* stmt = static_cast<AstNode*>(new AssignStmt());
    dynamic_cast<AssignStmt*>(stmt)->name = $1;
    dynamic_cast<AssignStmt*>(stmt)->value = $3;
    $$ = stmt;
}
;

whileStmt: WHILE OPEN_PAR expression CLOSE_PAR statement { 
    $$ = static_cast<AstNode*>($5);
}
;

printStmt: PRINT OPEN_PAR expression CLOSE_PAR SEMICOLON { 
    AstNode* print = static_cast<AstNode*>(new PrintStmt());
    if ($3) {
        dynamic_cast<PrintStmt*>(print)->content.push_back($3);
    }
    $$ = print;
}
;

returnStmt: RETURN expression SEMICOLON { 
    $$ = static_cast<AstNode*>($2);
}
| RETURN SEMICOLON { 
    $$ = nullptr;
}
;

exprStmt: funcCall SEMICOLON { 
    $$ = static_cast<AstNode*>($1);
}
;

block: OPEN_BRACE statement_list CLOSE_BRACE { 
    AstNode* block = static_cast<AstNode*>(new BlockStmt());
    if ($2) {
        dynamic_cast<BlockStmt*>(block)->stmts = *$2;
        delete $2;
    }
    $$ = block;
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
    AstNode* expr = static_cast<AstNode*>(new OrExpr());
    dynamic_cast<OrExpr*>(expr)->left = $1;
    dynamic_cast<OrExpr*>(expr)->right = $3;
    $$ = expr;
}
;

logicalAnd: equality { 
    $$ = static_cast<AstNode*>($1);
}
| logicalAnd AND equality { 
    AstNode* expr = static_cast<AstNode*>(new AndExpr());
    dynamic_cast<AndExpr*>(expr)->left = $1;
    dynamic_cast<AndExpr*>(expr)->right = $3;
    $$ = expr;
}
;

equality: comparison { 
    $$ = static_cast<AstNode*>($1);
}
| equality EQ comparison { 
    AstNode* expr = static_cast<AstNode*>(new EqualExpr());
    dynamic_cast<EqualExpr*>(expr)->left = $1;
    dynamic_cast<EqualExpr*>(expr)->right = $3;
    $$ = expr;
}
| equality NEQ comparison { 
    AstNode* expr = static_cast<AstNode*>(new NotEqualExpr());
    dynamic_cast<NotEqualExpr*>(expr)->left = $1;
    dynamic_cast<NotEqualExpr*>(expr)->right = $3;
    $$ = expr;
}
;

comparison: term { 
    $$ = static_cast<AstNode*>($1);
}
| comparison LT term { 
    AstNode* expr = static_cast<AstNode*>(new LtExpr());
    dynamic_cast<LtExpr*>(expr)->left = $1;
    dynamic_cast<LtExpr*>(expr)->right = $3;
    $$ = expr;
}
| comparison GT term { 
    AstNode* expr = static_cast<AstNode*>(new GtExpr());
    dynamic_cast<GtExpr*>(expr)->left = $1;
    dynamic_cast<GtExpr*>(expr)->right = $3;
    $$ = expr;
}
| comparison LTE term { 
    AstNode* expr = static_cast<AstNode*>(new LteExpr());
    dynamic_cast<LteExpr*>(expr)->left = $1;
    dynamic_cast<LteExpr*>(expr)->right = $3;
    $$ = expr;
}
| comparison GTE term { 
    AstNode* expr = static_cast<AstNode*>(new GteExpr());
    dynamic_cast<GteExpr*>(expr)->left = $1;
    dynamic_cast<GteExpr*>(expr)->right = $3;
    $$ = expr;
}
;

term: factor { 
    $$ = static_cast<AstNode*>($1);
}
| term OP_PLUS factor { 
    AstNode* expr = static_cast<AstNode*>(new AddExpr());
    dynamic_cast<AddExpr*>(expr)->left = $1;
    dynamic_cast<AddExpr*>(expr)->right = $3;
    $$ = expr;
}
| term OP_MINUS factor { 
    AstNode* expr = static_cast<AstNode*>(new SubExpr());
    dynamic_cast<SubExpr*>(expr)->left = $1;
    dynamic_cast<SubExpr*>(expr)->right = $3;
    $$ = expr;
}
;

factor: unary { 
    $$ = static_cast<AstNode*>($1);
}
| factor OP_MULT unary { 
    AstNode* expr = static_cast<AstNode*>(new MulExpr());
    dynamic_cast<MulExpr*>(expr)->left = $1;
    dynamic_cast<MulExpr*>(expr)->right = $3;
    $$ = expr;
}
| factor OP_DIV unary { 
    AstNode* expr = static_cast<AstNode*>(new DivExpr());
    dynamic_cast<DivExpr*>(expr)->left = $1;
    dynamic_cast<DivExpr*>(expr)->right = $3;
    $$ = expr;
}
| factor OP_MOD unary { 
    AstNode* expr = static_cast<AstNode*>(new ModExpr());
    dynamic_cast<ModExpr*>(expr)->left = $1;
    dynamic_cast<ModExpr*>(expr)->right = $3;
    $$ = expr;
}
;

unary: NOT unary { 
    AstNode* expr = static_cast<AstNode*>(new NotExpr());
    dynamic_cast<NotExpr*>(expr)->operand = $2;
    $$ = expr;
}
| OP_MINUS unary { 
    AstNode* expr = static_cast<AstNode*>(new NegExpr());
    dynamic_cast<NegExpr*>(expr)->operand = $2;
    $$ = expr;
}
| primary { 
    $$ = static_cast<AstNode*>($1);
}
;

primary: CONST_NUMBER { 
    AstNode* expr = static_cast<AstNode*>(new NumberExpr());
    dynamic_cast<NumberExpr*>(expr)->value = $1;
    $$ = expr;
}
| IDENTIFIER { 
    AstNode* expr = static_cast<AstNode*>(new IdentifierExpr());
    dynamic_cast<IdentifierExpr*>(expr)->name = $1;
    $$ = expr;
}
| funcCall { 
    $$ = static_cast<AstNode*>($1);
}
| OPEN_PAR expression CLOSE_PAR { 
    $$ = static_cast<AstNode*>($2);
}
;

funcCall: IDENTIFIER OPEN_PAR argListOpt CLOSE_PAR { 
    AstNode* call = static_cast<AstNode*>(new CallExpr());
    dynamic_cast<CallExpr*>(call)->callee = $1;
    if ($3) {
        dynamic_cast<CallExpr*>(call)->arguments = *$3;
        delete $3;
    }
    $$ = call;
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