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
    std::vector<std::string> codeStack; 
    int tempCounter = 0;
    int labelCounter = 0;
    std::unordered_map<std::string, std::string> symbolTable;
    std::unordered_map<std::string, std::string> variableAddresses; 

public:
    CodeGenerator() {}

    void saveAndClearCode() {
        codeStack.push_back(code.str());
        code.str("");
        code.clear();
    }

    std::string restoreCodeAndGetCapture() {
        std::string capturedCode = code.str();
        if (!codeStack.empty()) {
            code.str(codeStack.back());
            code.clear();
            code.seekp(0, std::ios::end); 
            codeStack.pop_back();
        } else {
            code.str("");
            code.clear();
        }
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
            std::string type = symbolTable[name];
            if (type == "i64*") {
                std::string actualAddr = variableAddresses[name];
                result.code = result.place + " = load i64, i64* " + actualAddr + "\n";
            } else {
                result.code = result.place + " = load i64, i64* %" + name + ".addr\n";
            }
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
        code << valueResult.code;        if (!varName.empty()) {
            auto it = symbolTable.find(varName);
            if (it != symbolTable.end() && it->second == "i64*") {
                code << "store i64 " << valueResult.place << ", i64* " << variableAddresses[varName] << "\n";
            } else {
                code << "store i64 " << valueResult.place << ", i64* %" << varName << ".addr\n";
            }
        } else {
            code << "; ERROR: assignment to empty variable\n";
        }
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
        
        if (op == "-") {
            result.type = "i64";
            result.code = operand.code;
            result.code += result.place + " = sub i64 0, " + operand.place + "\n";
        } else if (op == "!") {
            result.type = "i1";
            result.code = operand.code;
            std::string tempI1 = operand.place;
            if (operand.type == "i64") {
                tempI1 = newTemp();
                result.code += tempI1 + " = icmp ne i64 " + operand.place + ", 0\n";
            }
            result.code += result.place + " = xor i1 " + tempI1 + ", 1\n";
            result.type = "i1";
        }
        return result;
    }

    void genIfStatement(CodeResult& condition, CodeResult& thenCode, CodeResult& elseCode) {
        std::string LThen = newLabel();
        std::string LElse = newLabel();
        std::string LEnd = newLabel();

        code << condition.code;
        std::string condPlace = condition.place;
        if (condition.type == "i64") {
            condPlace = newTemp();
            code << condPlace << " = icmp ne i64 " << condition.place << ", 0\n";
        }

        code << "br i1 " << condPlace << ", label %" << LThen 
             << ", label %" << LElse << "\n";
        code << LThen << ":\n";
        code << thenCode.code;
        code << "br label %" << LEnd << "\n";

        code << LElse << ":\n";
        if (!elseCode.code.empty()) {
            code << elseCode.code;
        }
        code << "br label %" << LEnd << "\n";

        code << LEnd << ":\n";
    }

    void genWhileStatement(CodeResult& condition, CodeResult& body) {
        std::string LCond = newLabel();
        std::string LBody = newLabel();
        std::string LEnd = newLabel();

        code << "br label %" << LCond << "\n";
        code << LCond << ":\n";
        code << condition.code;

        std::string condPlace = condition.place;
        if (condition.type == "i64") {
            condPlace = newTemp();
            code << condPlace << " = icmp ne i64 " << condition.place << ", 0\n";
        }

        code << "br i1 " << condPlace << ", label %" << LBody 
             << ", label %" << LEnd << "\n";
        code << LBody << ":\n";
        code << body.code;
        code << "br label %" << LCond << "\n";
        code << LEnd << ":\n";
    }

    void genPrint(const std::vector<CodeResult>& expressions) {
        for (const auto& expr : expressions) {
            code << expr.code;
            std::string valToPrint = expr.place;
            if (expr.type == "i1") {
                valToPrint = newTemp();
                code << valToPrint << " = zext i1 " << expr.place << " to i64\n";
            }
            code << "call i32 (i8*, ...) @printf(i8* @str, i64 " << valToPrint << ")\n";
        }
    }

    void genFunctionDefinitionPreamble(const std::vector<CodeGenResult>& params) {
        for (const auto& param : params) {
            if (param.type == "i64*") {
                variableAddresses[param.place] = "%" + param.place;
                symbolTable[param.place] = "i64*";
            } else {
                variableAddresses[param.place] = "%" + param.place + ".addr";
                symbolTable[param.place] = "i64";
            }
        }
    }

    void genFunctionDefinition(const std::string& name, const std::vector<CodeGenResult>& params, const CodeGenResult& returnType, const std::string& bodyCode) {
        std::string returnTypeStr = (returnType.type == "void") ? "void" : "i64";
        
        code << "define " << returnTypeStr << " @" << name << "(";
        for (size_t i = 0; i < params.size(); ++i) {
            code << params[i].type << " %" << params[i].place;
            if (i < params.size() - 1) {
                code << ", ";
            }
        }
        code << ") {\n";
        code << "entry:\n";
        for (const auto& param : params) {
            if (param.type != "i64*") {
                std::string addrName = "%" + param.place + ".addr";
                code << "  " << addrName << " = alloca i64\n";
                code << "  store i64 %" << param.place << ", i64* " << addrName << "\n";
            }
        }

        code << bodyCode;  
        
        if (returnTypeStr == "void") {
            code << "  ret void\n";
        } else {
            code << "  ret i64 0\n";
        }
        code << "}\n";
    }

    CodeResult genFunctionCall(const std::string& funcName, const std::vector<CodeResult>& args) {
        CodeResult result;
        result.place = newTemp();
        result.type = "i64"; 
        
        std::string argsCode = "";
        std::string argsList = "";
        for (size_t i = 0; i < args.size(); ++i) {
            argsCode += args[i].code;
            argsList += args[i].type + " " + args[i].place;
            if (i < args.size() - 1) {
                argsList += ", ";
            }
        }

        result.code = argsCode;
        result.code += result.place + " = call i64 @" + funcName + "(" + argsList + ")\n";
        
        return result;
    }

    CodeResult genLogicalAnd(CodeResult& left, CodeResult& right) {
        CodeResult result;
        result.place = newTemp();
        result.type = "i1";
        
        result.code = left.code + right.code;
        
        std::string lPlace = left.place;
        if (left.type == "i64") {
            lPlace = newTemp();
            result.code += lPlace + " = icmp ne i64 " + left.place + ", 0\n";
        }
        std::string rPlace = right.place;
        if (right.type == "i64") {
            rPlace = newTemp();
            result.code += rPlace + " = icmp ne i64 " + right.place + ", 0\n";
        }

        result.code += result.place + " = and i1 " + lPlace + ", " + rPlace + "\n";
        
        return result;
    }

    CodeResult genLogicalOr(CodeResult& left, CodeResult& right) {
        CodeResult result;
        result.place = newTemp();
        result.type = "i1";
        
        result.code = left.code + right.code;

        std::string lPlace = left.place;
        if (left.type == "i64") {
            lPlace = newTemp();
            result.code += lPlace + " = icmp ne i64 " + left.place + ", 0\n";
        }
        std::string rPlace = right.place;
        if (right.type == "i64") {
            rPlace = newTemp();
            result.code += rPlace + " = icmp ne i64 " + right.place + ", 0\n";
        }

        result.code += result.place + " = or i1 " + lPlace + ", " + rPlace + "\n";
        
        return result;
    }

    void genReturnStmt(CodeResult* value) {
        if (value) {
            code << value->code;
            std::string retVal = value->place;
            if (value->type == "i1") {
                retVal = newTemp();
                code << retVal << " = zext i1 " << value->place << " to i64\n";
            }
            code << "  ret i64 " << retVal << "\n";
        } else {
            code << "  ret void\n";
        }
    }

    CodeResult genInput() {
        CodeResult result;
        result.place = ""; 
        result.type = "void";
        result.code = "; Input not implemented per user request\n";
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
        codeStack.clear();
    }
};

#endif 
