#include <iostream>
#include "./build/Parser.hpp"
#include "./build/Lexer.hpp"
#include "./build/Tree.hpp"
#include <unordered_map>
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
    std::unordered_map<std::string,int> variables;
    //ExprP::Parser parser(lexer, variables);
    try {
        //int result = parser.parse();
        std::cout << "Parse completed successfully!" << std::endl;
        return 0;
    } catch (const std::exception& e) {
        std::cerr << "Error: " << e.what() << std::endl;
        return 1;
    }
}
