#include "icg_util.h"

void init_icg() {
    codeout << ".MODEL SMALL\r\n.STACK 100H\r\n.DATA\r\n\r\n";
    codeout << "CR EQU 0DH\r\nLF EQU 0AH\r\nnumber DB \"00000$\"\r\n";
    tempout << ".CODE\r\n";
}

void generate_printing_function() {
    // first the number printing function
    tempout << "PRINT PROC\r\n";
    tempout << "\tPUSH SI\r\n\tPUSH AX\r\n\tPUSH BX\r\n\tPUSH CX\r\n\tPUSH DX\r\n";
    tempout << "\tLEA SI, NUMBER\r\n\tADD SI, 5\r\n";
    tempout << "\t; FIRST CHECK IF THE NUMBER IN AX IS NEGATIVE\r\n";
    tempout << "\tMOV BX, 1\r\n\tSHL BX, 15 ; NOW BX IS 2^15\r\n";
    tempout << "\tTEST AX, BX\r\n\t; IF THE SIGN BIT OF AX IS 1, THEN JZ WILL NOT GET EXECUTED\r\n";
    tempout << "\tJZ PRINT_LOOP\r\n\t; OTHERWISE THE NUMBER IS NEGATIVE\r\n";
    tempout << "\tMOV BX, 1\r\n\tNEG AX\r\n";

    tempout << "\tPRINT_LOOP:\r\n\t\tDEC SI\r\n\t\tMOV DX, 0\r\n\t\t; DX:AX = 0000:AX\r\n";
    tempout << "\t\tMOV CX, 10\r\n\t\tDIV CX\r\n\t\tADD DL, '0'\r\n\t\tMOV [SI], DL\r\n";
    tempout << "\t\tCMP AX, 0\r\n\t\tJNE PRINT_LOOP\r\n";

    tempout << "\tCMP BX, 1\r\n\tJNE DO_PRINT_NUMBER\r\n\tMOV DL, '-'\r\n\tMOV AH, 2\r\n\tINT 21H\r\n";
    tempout << "\tDO_PRINT_NUMBER:\r\n\t\tMOV DX, SI\r\n\t\tMOV AH, 09\r\n\t\tINT 21H\r\n";
    tempout << "\tPOP DX\r\n\tPOP CX\r\n\tPOP BX\r\n\tPOP AX\r\n\tPOP SI\r\n\tRET\r\nPRINT ENDP\r\n\r\n";

    // now the newline printing function
    tempout << "NEWLINE PROC\r\n\tPUSH AX\r\n\tPUSH DX\r\n\tMOV AH, 02\r\n\tMOV DL, CR\r\n\tINT 21H\r\n\tMOV DL, LF\r\n\tINT 21H\r\n\tPOP DX\r\n\tPOP AX\r\n\tRET\r\nNEWLINE ENDP\r\n\r\n";
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
    codeappend.close();
}