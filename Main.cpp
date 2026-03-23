#include <iostream>
#include "./build/Parser.hpp"
#include "./build/Lexer.hpp"
#include "./build/Tree.hpp"
#include "CodeGenerator.hpp"
#include <memory>
#include <fstream>

std::string generateLLVMCodeFromAST(AstNode* root) {
    if (!root) return "";
    
    CodeGenerator gen;
    root->evaluate(gen);
    std::stringstream llvmCode;
    llvmCode << "declare i32 @printf(i8*, ...)\n";
    llvmCode << "@str = private constant [4 x i8] c\"%d \\00\" \n";
    llvmCode << gen.getCode();
    
    return llvmCode.str();
}

int main(int argc, char* argv[]) {
    if (argc < 2) {
        return 1;
    }
    
    std::ifstream file(argv[1]);
    if (!file.is_open()) {
        std::cerr << "Error opening file: " << argv[1] << std::endl;
        return 1;
    }
    Lexer lexer(file);
    AstNode* root = nullptr;
    ExprP::Parser my_parser(lexer, root);

    try{
        my_parser();
        if (root) {
            std::cout << "AST:\n";
            std::cout << root->toString() << std::endl;
            std::cout << "\nSyntax correct\n";
            
                std::string llvmCode = generateLLVMCodeFromAST(root);
                std::ofstream llvmFile("EJECUTABLE.ll");
                if (llvmFile.is_open()) {
                    llvmFile << llvmCode;
                    llvmFile.close();
                    std::cout << "\nLLVM IR written to EJECUTABLE.ll\n";
                } else {
                    std::cerr << "Error: Could not open EJECUTABLE.ll for writing\n";
                }
        }
    }catch(const ExprP::Parser::syntax_error& e){
        std::cerr << "Error de sintaxis: " << e.what() << "\n";
    }

    return 0;
}
