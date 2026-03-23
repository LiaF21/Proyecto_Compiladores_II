#ifndef CODEGENERATOR_HPP
#define CODEGENERATOR_HPP

#include <string>
#include <sstream>
#include <vector>
#include <unordered_map>
#include <memory>

class CodeGenerator;

struct CodeGenResult {
    std::string code;       
    std::string place;      
    std::string type;       
};

class CodeGenerator {
public:
    using CodeResult = CodeGenResult;

private:
    std::stringstream code;
    std::stringstream savedCode; r
    int tempCounter = 0;
    int labelCounter = 0;
    std::unordered_map<std::string, std::string> symbolTable;
    std::unordered_map<std::string, std::string> variableAddresses; 

public:
    CodeGenerator() {}

    void saveAndClearCode() {
        savedCode << code.str();
        code.str("");
        code.clear();
    }

    std::string restoreCodeAndGetCapture() {
        std::string capturedCode = code.str();
        code.str(savedCode.str());
        code.clear();
        savedCode.str("");
        savedCode.clear();
        return capturedCode;
    }

    std::string newTemp() {
        return "%t" + std::to_string(tempCounter++);
    }

    std::string newLabel() {
        return "L" + std::to_string(labelCounter++);
    }

    CodeResult genIntLiteral(long value) {
        CodeResult result;
        result.place = newTemp();
        result.type = "i64";
        result.code = result.place + " = add i64 0, " + std::to_string(value) + "\n";
        return result;
    }

    CodeResult genVariable(const std::string& name) {
        CodeResult result;
        result.place = newTemp();
        result.type = "i64";
        
        auto it = variableAddresses.find(name);
        if (it != variableAddresses.end()) {
            result.code = result.place + " = load i64, i64* %" + name + ".addr\n";
        } else {
            result.code = ""; 
        }
        return result;
    }

    CodeResult genArithmeticExpr(const std::string& op, CodeResult& left, CodeResult& right) {
        CodeResult result;
        result.place = newTemp();
        result.type = "i64";
        
        std::string llvmOp;
        if (op == "+") llvmOp = "add";
        else if (op == "-") llvmOp = "sub";
        else if (op == "*") llvmOp = "mul";
        else if (op == "/") llvmOp = "sdiv";
        else if (op == "%") llvmOp = "srem";

        result.code = left.code + right.code;
        result.code += result.place + " = " + llvmOp + " i64 " + 
                      left.place + ", " + right.place + "\n";
        
        return result;
    }

    CodeResult genComparison(const std::string& op, CodeResult& left, CodeResult& right) {
        CodeResult result;
        result.place = newTemp();
        result.type = "i1"; 

        std::string cmpOp;
        if (op == "<") cmpOp = "slt";
        else if (op == "<=") cmpOp = "sle";
        else if (op == ">") cmpOp = "sgt";
        else if (op == ">=") cmpOp = "sge";
        else if (op == "==") cmpOp = "eq";
        else if (op == "!=") cmpOp = "ne";

        result.code = left.code + right.code;
        result.code += result.place + " = icmp " + cmpOp + " i64 " + 
                      left.place + ", " + right.place + "\n";
        
        return result;
    }

    void genAssignment(const std::string& varName, CodeResult& valueResult) {
        code << valueResult.code;
        code << "store i64 " << valueResult.place << ", i64* %" << varName << ".addr\n";
    }

    void genVarDeclaration(const std::string& varName, CodeResult* initValue = nullptr) {
        code << "%" << varName << ".addr = alloca i64\n";
        symbolTable[varName] = "i64";
        variableAddresses[varName] = "%" + varName + ".addr";
        
        if (initValue) {
            code << initValue->code;
            code << "store i64 " << initValue->place << ", i64* %" << varName << ".addr\n";
        }
    }

    CodeResult genUnaryExpr(const std::string& op, CodeResult& operand) {
        CodeResult result;
        result.place = newTemp();
        result.type = "i64";
        result.code = operand.code;
        return result;
    }

    void genIfStatement(CodeResult& condition, CodeResult& thenCode, CodeResult& elseCode) {
        std::string LThen = newLabel();
        std::string LElse = newLabel();
        std::string LEnd = newLabel();

        code << condition.code;
        code << "br i1 " << condition.place << ", label %" << LThen 
             << ", label %" << LElse << "\n";
        code << LThen << ":\n";
        code << thenCode.code;
        code << "br label %" << LEnd << "\n";

        if (!elseCode.code.empty()) {
            code << LElse << ":\n";
            code << elseCode.code;
            code << "br label %" << LEnd << "\n";
        } else {
            code << LElse << ":\n";
            code << "br label %" << LEnd << "\n";
        }

        code << LEnd << ":\n";
    }

    void genWhileStatement(CodeResult& condition, CodeResult& body) {
        std::string LCond = newLabel();
        std::string LBody = newLabel();
        std::string LEnd = newLabel();

        code << "br label %" << LCond << "\n";
        code << LCond << ":\n";
        code << condition.code;
        code << "br i1 " << condition.place << ", label %" << LBody 
             << ", label %" << LEnd << "\n";
        code << LBody << ":\n";
        code << body.code;
        code << "br label %" << LCond << "\n";
        code << LEnd << ":\n";
    }

    void genPrint(const std::vector<CodeResult>& expressions) {
        for (const auto& expr : expressions) {
            code << expr.code;
            code << "call i32 (i8*, ...) @printf(i8* @str, i64 " << expr.place << ")\n";
        }
    }

    void genFunctionDefinition(const std::string& name, const std::vector<CodeGenResult>& params, const CodeGenResult& returnType, const std::string& bodyCode) {
        std::string returnTypeStr = (returnType.type == "void") ? "void" : "i64";
        
        code << "define " << returnTypeStr << " @" << name << "(";
        for (size_t i = 0; i < params.size(); ++i) {
            code << "i64 %" << params[i].place;
            if (i < params.size() - 1) {
                code << ", ";
            }
        }
        code << ") {\n";
        code << "entry:\n";
        code << bodyCode;  
        
        if (returnTypeStr == "void") {
            code << "ret void\n";
        }
        code << "}\n";
    }


    CodeResult genFunctionCall(const std::string& funcName, const std::vector<CodeResult>& args) {
        CodeResult result;
        result.place = newTemp();
        result.type = "i64"; 
        return result;
    }


    CodeResult genLogicalAnd(CodeResult& left, CodeResult& right) {
        CodeResult result;
        result.place = newTemp();
        result.type = "i1";
        
        result.code = left.code + right.code;
        result.code += result.place + " = and i1 " + left.place + ", " + right.place + "\n";
        
        return result;
    }

    CodeResult genLogicalOr(CodeResult& left, CodeResult& right) {
        CodeResult result;
        result.place = newTemp();
        result.type = "i1";
        
        result.code = left.code + right.code;
        result.code += result.place + " = or i1 " + left.place + ", " + right.place + "\n";
        
        return result;
    }

  
    void genReturnStmt(CodeResult* value) {
        if (value) {
            code << value->code;
            code << "ret i64 " << value->place << "\n";
        } else {
            code << "ret void\n";
        }
    }

    CodeResult genInput() {
        CodeResult result;
        result.place = newTemp();
        result.type = "i64";;
        return result;
    }

    std::string getCode() const {
        return code.str();
    }

    void reset() {
        code.str("");
        code.clear();
        tempCounter = 0;
        labelCounter = 0;
        symbolTable.clear();
        variableAddresses.clear();
    }
};

#endif 
