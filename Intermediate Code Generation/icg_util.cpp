#include "icg_util.h"

void init_icg() {
    codeout << ".MODEL SMALL\r\n.STACK 100H\r\n\r\n.DATA\r\n";
    codeout << "\tCR EQU 0DH\r\n\tLF EQU 0AH\r\n\tnumber DB \"00000$\"\r\n";
    tempout << "\r\n.CODE\r\n";
    tempout << "MAIN PROC\r\n";
    tempout << "\tMOV AX, @DATA\r\n\tMOV DS, AX\r\n\tMOV BP, SP\r\n";
}

void generate_printing_function() {
    // first the number printing function
    tempout << "\r\n; PRINT WHAT IS IN REGISTER AX\r\n";
    tempout << "PRINT PROC\r\n";
    tempout << "\tPUSH SI\r\n\tPUSH AX\r\n\tPUSH BX\r\n\tPUSH CX\r\n\tPUSH DX\r\n";
    tempout << "\tLEA SI, NUMBER\r\n\tADD SI, 5\r\n";
    tempout << "\t; FIRST CHECK IF THE NUMBER IN AX IS NEGATIVE\r\n";
    tempout << "\tMOV BX, 1\r\n\tSHL BX, 15 ; NOW BX IS 2^15\r\n";
    tempout << "\tTEST AX, BX\r\n\t; IF THE SIGN BIT OF AX IS 1, THEN JZ WILL NOT GET EXECUTED\r\n";
    tempout << "\tJZ PRINT_LOOP\r\n\t; OTHERWISE THE NUMBER IS NEGATIVE\r\n";
    tempout << "\tMOV BX, 1\r\n\tNEG AX\r\n";

    tempout << "\tPRINT_LOOP:\r\n\tDEC SI\r\n\tMOV DX, 0\r\n\t; DX:AX = 0000:AX\r\n";
    tempout << "\tMOV CX, 10\r\n\tDIV CX\r\n\tADD DL, '0'\r\n\tMOV [SI], DL\r\n";
    tempout << "\tCMP AX, 0\r\n\tJNE PRINT_LOOP\r\n";

    tempout << "\tCMP BX, 1\r\n\tJNE DO_PRINT_NUMBER\r\n\tMOV DL, '-'\r\n\tMOV AH, 2\r\n\tINT 21H\r\n";
    tempout << "\tDO_PRINT_NUMBER:\r\n\tMOV DX, SI\r\n\tMOV AH, 09\r\n\tINT 21H\r\n";
    tempout << "\tPOP DX\r\n\tPOP CX\r\n\tPOP BX\r\n\tPOP AX\r\n\tPOP SI\r\n\tRET\r\nPRINT ENDP\r\n\r\n";

    // now the newline printing function
    tempout << "NEWLINE PROC\r\n\tPUSH AX\r\n\tPUSH DX\r\n\tMOV AH, 02\r\n\tMOV DL, CR\r\n\tINT 21H\r\n\tMOV DL, LF\r\n\tINT 21H\r\n\tPOP DX\r\n\tPOP AX\r\n\tRET\r\nNEWLINE ENDP\r\n";
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