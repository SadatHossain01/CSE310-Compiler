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
    tempout << "\r\n\t; dividend has to be in DX:AX\r\n\t; divisor in source, CX\r\n\tMOV CX, 10\r\n";
    tempout << "\tXOR BL, BL ; BL will store the length of number\r\n\tCMP AX, 0\r\n\tJGE STACK_OP ; number is positive\r\n";
    tempout << "\tMOV BH, 1; number is negative\r\n\tNEG AX\r\n\r\nSTACK_OP:\r\n\tXOR DX, DX\r\n\tDIV CX\r\n";
    tempout << "\t; quotient in AX, remainder in DX\r\n\tPUSH DX\r\n\tINC BL ; len++\r\n\tCMP AX, 0\r\n\tJG STACK_OP\r\n";
    tempout << "\r\n\tMOV AH, 02\r\n\tCMP BH, 1 ; if negative, print a '-' sign first\r\n\tJNE PRINT_LOOP\r\n";
    tempout << "\tMOV DL, '-'\r\n\tINT 21H\r\n\r\nPRINT_LOOP:\r\n\tPOP DX\r\n\tXOR DH, DH\r\n\tADD DL, '0'\r\n\tINT 21H\r\n";
    tempout << "\tDEC BL\r\n\tCMP BL, 0\r\n\tJG PRINT_LOOP\r\n\r\n\tPOP DX\r\n\tPOP CX\r\n\tPOP BX\r\n\tPOP AX\r\n\tRET\r\nPRINT_OUTPUT ENDP\r\n";

    // now the newline printing function
    tempout << "\r\nPRINT_NEWLINE PROC\r\n\tPUSH AX\r\n\tPUSH DX\r\n\tMOV AH, 02\r\n\tMOV DL, 0DH\r\n\tINT 21H\r\n";
    tempout << "\tMOV DL, 0AH\r\n\tINT 21H\r\n\tPOP DX\r\n\tPOP AX\r\n\tRET\r\nPRINT_NEWLINE ENDP\r\n";
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

void print_id(const string& s) { tempout << "\tPUSH AX\r\n\tMOV AX, " << s << "\r\n\tCALL PRINT_OUTPUT\r\n\tCALL PRINT_NEWLINE\r\n\tPOP AX\r\n"; }