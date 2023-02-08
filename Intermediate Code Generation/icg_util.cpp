#include "icg_util.h"

void init_icg() {
    codeout << ".MODEL SMALL\r\n.STACK 100H\r\n\r\n.DATA\r\n";
    tempout << "\r\n.CODE\r\n";
    tempout << "MAIN PROC\r\n";
    tempout << "\tMOV AX, @DATA\r\n\tMOV DS, AX\r\n\tMOV BP, SP\r\n";
}

void generate_printing_function() {
    // first the number printing function
    tempout << "\r\nPRINT_OUTPUT PROC\r\n\tPUSH AX\r\n\tPUSH BX\r\n\tPUSH CX\r\n\tPUSH DX\r\n";
    tempout
        << "\r\n\t; dividend has to be in DX:AX\r\n\t; divisor in source, CX\r\n\tMOV CX, 10\r\n";
    tempout << "\tXOR BL, BL ; BL will store the length of number\r\n\tCMP AX, 0\r\n\tJGE STACK_OP "
               "; number is positive\r\n";
    tempout << "\tMOV BH, 1; number is negative\r\n\tNEG AX\r\n\r\nSTACK_OP:\r\n\tXOR DX, "
               "DX\r\n\tDIV CX\r\n";
    tempout << "\t; quotient in AX, remainder in DX\r\n\tPUSH DX\r\n\tINC BL ; len++\r\n\tCMP AX, "
               "0\r\n\tJG STACK_OP\r\n";
    tempout << "\r\n\tMOV AH, 02\r\n\tCMP BH, 1 ; if negative, print a '-' sign first\r\n\tJNE "
               "PRINT_LOOP\r\n";
    tempout << "\tMOV DL, '-'\r\n\tINT 21H\r\n\r\nPRINT_LOOP:\r\n\tPOP DX\r\n\tXOR DH, DH\r\n\tADD "
               "DL, '0'\r\n\tINT 21H\r\n";
    tempout << "\tDEC BL\r\n\tCMP BL, 0\r\n\tJG PRINT_LOOP\r\n\r\n\tPOP DX\r\n\tPOP CX\r\n\tPOP "
               "BX\r\n\tPOP AX\r\n\tRET\r\nPRINT_OUTPUT ENDP\r\n";

    // now the newline printing function
    tempout << "\r\nPRINT_NEWLINE PROC\r\n\tPUSH AX\r\n\tPUSH DX\r\n\tMOV AH, 02\r\n\tMOV DL, "
               "0DH\r\n\tINT 21H\r\n";
    tempout
        << "\tMOV DL, 0AH\r\n\tINT 21H\r\n\tPOP DX\r\n\tPOP AX\r\n\tRET\r\nPRINT_NEWLINE ENDP\r\n";
}

void generate_final_assembly() {
    // append the content of temp.asm file to code.asm file
    codeout.close();
    tempout.close();
    ofstream codeappend;
    ifstream tempin;
    string line;
    codeappend.open("code.asm", std::ios_base::app);
    tempin.open("temp.asm");
    while (getline(tempin, line)) {
        codeappend << line;
    }
    codeappend << "\r\nEND MAIN\r\n";
    codeappend.close();
    remove("temp.asm");  // delete the temporary file
}

void print_id(const string& s) {
    tempout << "\tMOV SP, BP ; Line No: " << line_count << "\r\n";
    tempout << "\tADD SP, " << current_offset << " ; Line No: " << line_count << "\r\n";
    tempout << "\tPUSH AX ; Line No: " << line_count << "\r\n";
    tempout << "\tMOV AX, " << s << " ; Line No: " << line_count << "\r\n";
    tempout << "\tCALL PRINT_OUTPUT ; Line No: " << line_count << "\r\n";
    tempout << "\tCALL PRINT_NEWLINE ; Line No: " << line_count << "\r\n";
    tempout << "\tPOP AX ; Line No: " << line_count << "\r\n";
}

string get_variable_address(SymbolInfo* sym) {
    int offset = sym->get_stack_offset();
    string name = sym->get_name();
    if (offset == -1) return name;  // global variable
    else return "[BP" + (offset ? ((offset > 0 ? "+" : "") + to_string(offset)) : "") + "]";
}
string get_variable_address(const string& name, const int offset) {
    if (offset == -1) return name;  // global variable
    else return "[BP" + (offset ? ((offset > 0 ? "+" : "") + to_string(offset)) : "") + "]";
}

void generate_code(const string& code, const string& comment) {
    tempout << "\t" << code << " ; Line No: " << line_count
            << (comment.empty() ? "" : ", " + comment) << "\r\n";
}

void generate_incop_code(SymbolInfo* sym, const string& op) {
    generate_code("MOV AX, " + get_variable_address(sym));
    generate_code(op + " " + get_variable_address(sym));
}

void generate_logicop_code(const string& op) {
    if (op == "NOT") {
        generate_code("CMP AX, 0");
        generate_code("JZ, L" + to_string(label_count++));
        tempout << "L" << label_count - 1 << ":\r\n";
        generate_code("MOV AX, 1");
        generate_code("JMP L" + to_string(++label_count));
        tempout << "L" << label_count - 1 << ":\r\n";
        generate_code("MOV AX, 0");
        tempout << "L" << label_count++ << ":\r\n";
    } else {
        if (op == "&&") generate_code("AND AX, BX");
        else if (op == "||") generate_code("OR AX, BX");
    }
}

void generate_addop_code(const string& op) {
    // first operand is in BX, second one is in AX
    if (op == "+") {
        generate_code("ADD AX, BX");
    } else if (op == "-") {
        generate_code("SUB AX, BX");
        generate_code("NEG AX");
    }
}

void generate_mulop_code(const string& op) {
    // first operand is in BX, second one is in AX
    if (op == "*") {
        generate_code("IMUL BX");  // result gets stored in DX:AX, only AX should do (including
                                   // negative result cases)
    } else {
        // we want to do BX / AX
        // so take the dividend from BX to AX first
        generate_code("MOV BX, CX");
        generate_code("MOV AX, BX");
        generate_code("MOV BX, CX");
        generate_code("IDIV BX");

        if (op == "/") {
            // quotient is in AL, so sign extend AL to AX
            generate_code(
                "CBW");  // extends the sign of AL to AH register,
                         // http://www.c-jump.com/CIS77/MLabs/M11arithmetic/M11_0110_cbw_cwd_cdq.htm
        } else if (op == "%") {
            // remainder is in AH, so move it to AX
            generate_code("SAR AH, 8");
        }
    }
}

void generate_relop_code(const string& op) {
    // first operand is in BX, second one is in AX
    string jmpi = "";
    if (op == "<") jmpi = "JL";
    else if (op == "<=") jmpi = "JLE";
    else if (op == ">") jmpi = "JG";
    else if (op == ">=") jmpi = "JGE";
    else if (op == "==") jmpi = "JE";
    else if (op == "!=") jmpi = "JNE";
    generate_code("CMP BX, AX");
    generate_code(jmpi + " L" + to_string(label_count++));
    tempout << "L" << label_count - 1 << ":\r\n";
    generate_code("MOV AX, 1");
    generate_code("JMP L" + to_string(++label_count));
    tempout << "L" << label_count - 1 << ":\r\n";
    generate_code("MOV AX, 0");
    tempout << "L" << label_count++ << ":\r\n";
}