#include <iostream>
#include "./build/Parser.hpp"
#include "./build/Lexer.hpp"
#include "./build/Tree.hpp"
#include <memory>
#include <fstream>

int main(int argc, char* argv[]) {
    if (argc < 2) {
        std::cerr << "Usage: " << argv[0] << " <Archivo>" << std::endl;
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
            std::cout << root->toString() << std::endl;
        }
        std::cout<<"Syntax correct\n";
    }catch(const ExprP::Parser::syntax_error& e){
        std::cerr << "Error de sintaxis: " << e.what() << "\n";
    }


    return 0;
}
