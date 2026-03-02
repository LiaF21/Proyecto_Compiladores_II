#include <iostream>
#include "./build/Parser.hpp"
#include "./build/Lexer.hpp"
#include "tree.hpp"
#include <unordered_map>
#include <memory>

int main() {
    Lexer lexer(std::cin);
    std::unordered_map<std::string,int> variables;
    ExprP::Parser parser(lexer, variables);
    try {
        int result = parser.parse();
        std::cout << "Parse completed successfully!" << std::endl;
        return 0;
    } catch (const std::exception& e) {
        std::cerr << "Error: " << e.what() << std::endl;
        return 1;
    }
}
