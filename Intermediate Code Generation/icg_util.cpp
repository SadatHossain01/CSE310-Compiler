#include "icg_util.h"

void init_icg() {
    codeout << ".MODEL SMALL\r\n.STACK 1000H\r\n\r\n.DATA\r\n";
    tempout << "\r\n.CODE\r\n";
    tempout << "MAIN PROC\r\n";
    tempout << "\tMOV AX, @DATA\r\n\tMOV DS, AX\r\n\tMOV BP, SP\r\n";
    temp_file_lc = 7;
}

void generate_printing_function() {
    // first the number printing function
    tempout << "\r\nPRINT_OUTPUT PROC\r\n\tPUSH AX\r\n\tPUSH BX\r\n\tPUSH CX\r\n\tPUSH DX\r\n";
    tempout << "\t; dividend has to be in DX:AX\r\n\t; divisor in source, CX\r\n\tMOV CX, 10\r\n";
    tempout << "\tXOR BL, BL ; BL will store the length of number\r\n\tCMP AX, 0\r\n\tJGE STACK_OP "
               "; number is positive\r\n";
    tempout << "\tMOV BH, 1; number is negative\r\n\tNEG AX\r\nSTACK_OP:\r\n\tXOR DX, "
               "DX\r\n\tDIV CX\r\n";
    tempout << "\t; quotient in AX, remainder in DX\r\n\tPUSH DX\r\n\tINC BL ; len++\r\n\tCMP AX, "
               "0\r\n\tJG STACK_OP\r\n";
    tempout << "\tMOV AH, 02\r\n\tCMP BH, 1 ; if negative, print a '-' sign first\r\n\tJNE "
               "PRINT_LOOP\r\n";
    tempout << "\tMOV DL, '-'\r\n\tINT 21H\r\nPRINT_LOOP:\r\n\tPOP DX\r\n\tXOR DH, DH\r\n\tADD "
               "DL, '0'\r\n\tINT 21H\r\n";
    tempout << "\tDEC BL\r\n\tCMP BL, 0\r\n\tJG PRINT_LOOP\r\n\tPOP DX\r\n\tPOP CX\r\n\tPOP "
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
    codeappend.open("code.asm", ios::app);
    tempin.open("temp.asm");
    int line_no_here = 0;
    while (getline(tempin, line)) {
        line_no_here++;
        // cerr << "Line: " << line << endl;
        string trimmed_line = trim(line);
        // cerr << "Trimmed: " << trimmed_line << endl;
        vector<string> operands = get_operands(trimmed_line);
        if (!trimmed_line.empty() && trimmed_line.front() == 'J' && operands.size() == 1) {
            // cerr << "Empty jump found at line " << line_no_here << endl;
            while (line.back() == '\t' || line.back() == ' ' || line.back() == '\r' ||
                   line.back() == '\n')
                line.pop_back();
            line += " " + label_map[line_no_here];
            useful_labels.insert(label_map[line_no_here]);
        }
        codeappend << line << endl;
    }
    useful_labels.insert("STACK_OP");
    useful_labels.insert("PRINT_LOOP");
    codeappend << "\r\nEND MAIN\r\n";
    codeappend.close();
    tempin.close();
    // print all of label_map
    // for (auto it = label_map.begin(); it != label_map.end(); it++) {
    //     cerr << it->first << " " << it->second << endl;
    // }
    // remove("temp.asm");  // delete the temporary file
}

void optimize_code() {
    // read from code.asm, print to optimized_code.asm
    // cerr << "Useful Labels:" << endl;
    // for (auto p : useful_labels) {
    //     cerr << p << endl;
    // }
    ifstream fin;
    ofstream fout;
    fin.open("code.asm");
    fout.open("optimized_code.asm");
    string line;
    while (getline(fin, line)) {
        // cerr << "Line: " << line << endl;
        string trimmed_line = trim(line);
        // cerr << "Trimmed Line: " << trimmed_line << endl;
        // cerr << "Ended" << endl;
        if (trimmed_line.back() == ':') {
            // this is a label
            string label = trimmed_line.substr(0, trimmed_line.size() - 1);
            // cerr << label << " found" << endl;
            if (useful_labels.count(label) == 0) continue;
        }
        fout << line << endl;
    }
    fin.close();
    fout.close();
}

void print_id(const string& s) {
    push_to_stack("AX");
    generate_code("MOV AX, " + s);
    generate_code("CALL PRINT_OUTPUT");
    generate_code("CALL PRINT_NEWLINE");
    pop_from_stack("AX");
}

string get_variable_address(SymbolInfo* sym) {
    int offset = sym->get_stack_offset();
    string name = sym->get_name();
    if (offset == -1) return name;  // global variable
    else return "[BP" + (offset ? ((offset > 0 ? "-" : "") + to_string(offset)) : "") + "]";
}

string get_variable_address(const string& name, const int offset) {
    if (offset == -1) return name;  // global variable
    else return "[BP" + (offset ? ((offset > 0 ? "-" : "") + to_string(offset)) : "") + "]";
}

void push_to_stack(const string& name) {
    // generate_code("MOV SP, BP");
    // generate_code("SUB SP, " + to_string(current_offset));
    generate_code("PUSH " + name);
}

void pop_from_stack(const string& name) {
    generate_code("POP " + name);
    // generate_code("MOV SP, BP");
    // generate_code("SUB SP, " + to_string(current_offset));
}

void generate_code(const string& code, const string& comment) {
    if (printed_line_count < line_count) {
        tempout << "\t; Line No: " << line_count << "\r\n";
        printed_line_count = line_count;
        temp_file_lc++;
    }
    tempout << "\t";
    tempout << code << (comment.empty() ? "" : "; " + comment) << "\r\n";
    temp_file_lc++;
}

void print_label(string label) {
    // increment label outside the function
    if (printed_line_count < line_count) {
        tempout << "\t; Line No: " << line_count << "\r\n";
        printed_line_count = line_count;
        temp_file_lc++;
    }
    tempout << label << ":\r\n";
    temp_file_lc++;
}

void print_label(int label) { print_label("L" + to_string(label)); }

void generate_incop_code(SymbolInfo* sym, const string& op) {
    if (sym->get_type() != "FROM_ARRAY") {
        string address = get_variable_address(sym);
        generate_code("MOV AX, " + address);
        generate_code(op + " WORD PTR " + address);
    } else {
        if (sym->get_stack_offset() == -1) {
            // element of some global array
            generate_code("LEA SI, " + sym->get_name());
            generate_code("SHL CX, 1");
            generate_code("ADD SI, CX");
            generate_code("MOV AX, [SI]");
            generate_code(op + " WORD PTR [SI]");
        } else {
            // element of some local array, index is in CX
            generate_code("SHL CX, 1");
            generate_code("ADD CX, " + to_string(sym->get_stack_offset()));
            generate_code("MOV DI, BP");
            generate_code("SUB DI, CX");
            generate_code("MOV AX, [DI]");
            generate_code(op + " WORD PTR [DI]");
        }
    }
    push_to_stack("AX");
}

void generate_logicop_code(const string& op) {
    if (op == "NOT") {
        generate_code("CMP AX, 0");
        generate_code("JE L" + to_string(label_count++));
        print_label(label_count - 1);
        generate_code("MOV AX, 1");
        generate_code("JMP L" + to_string(++label_count));
        print_label(label_count - 1);
        generate_code("XOR AX, AX");
        print_label(label_count++);

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
    }
}

void generate_mulop_code(const string& op) {
    // first operand is in BX, second one is in AX
    if (op == "*") {
        generate_code("IMUL BX");  // result gets stored in DX:AX, only AX should do (including
                                   // negative result cases)
    } else {
        // since the divisor is BX, it will be a division of word form, hence dividend will be in
        // DX:AX
        generate_code("XOR DX, DX");
        generate_code("IDIV BX");

        if (op == "/") {
            // quotient is in AX
            // nothing needed to be done
        } else if (op == "%") {
            // remainder is in DX
            generate_code("MOV AX, DX");
        }
    }
}

void generate_relop_code(const string& op, SymbolInfo* sym) {
    // first operand is in BX, second one is in AX
    string jmpi = "";
    if (op == "<") jmpi = "JL";
    else if (op == "<=") jmpi = "JLE";
    else if (op == ">") jmpi = "JG";
    else if (op == ">=") jmpi = "JGE";
    else if (op == "==") jmpi = "JE";
    else if (op == "!=") jmpi = "JNE";
    if (op == "jnz") {
        generate_code("CMP AX, 0");
        generate_code("JNE");
    } else {
        generate_code("CMP AX, BX");
        generate_code(jmpi);  // keeping label empty for now
    }
    // cerr << "Generating a jump instruction at " << temp_file_lc - 1 << endl;
    sym->add_to_truelist(temp_file_lc - 1);
    generate_code("JMP");
    // cerr << "Generating a jump instruction at " << temp_file_lc - 1 << endl;
    sym->add_to_falselist(temp_file_lc - 1);
}

vector<int> merge(const vector<int>& v1, const vector<int>& v2) {
    vector<int> v;
    v.reserve(v1.size() + v2.size());
    v.insert(v.end(), v1.begin(), v1.end());
    v.insert(v.end(), v2.begin(), v2.end());
    return v;
}

void backpatch(const vector<int>& v, string label) {
    // show all contents of v to cerr
    // if (!v.empty()) {
    //     cerr << "Backpatching ";
    //     for (int i : v) {
    //         cerr << i << " ";
    //     }
    //     cerr << "to label " << label << endl;
    // }

    for (int i : v) {
        label_map[i] = label;
    }
}

string trim(const string& line) {
    vector<char> c = {' ', '\t', '\r', '\n'};
    int start = 0;
    int size = line.size();
    while (start < size && find(c.begin(), c.end(), line[start]) != c.end()) start++;
    if (start == size) return "";
    int end = size - 1;
    while (end > start && find(c.begin(), c.end(), line[end]) != c.end()) end--;
    return line.substr(start, end - start + 1);
}

vector<string> get_operands(const string& line) {
    // split the string, delimiter is space
    vector<string> operands;
    int idx = 0;
    while (idx < line.size()) {
        int start = idx;
        while (idx < line.size() && line[idx] != ' ') idx++;
        if (idx > start) operands.push_back(line.substr(start, idx - start));
        idx++;
    }
    return operands;
}