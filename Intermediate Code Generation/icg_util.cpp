#include "icg_util.h"

void init_icg() {
    codeout << ".MODEL SMALL\n.STACK 100h\n.DATA\n\n";
    codeout << "CR EQU 0DH\nLF EQU 0AH\n number DB\"00000$\"";
    tempout << ".CODE\n";
}

void generate_printing_function() {}

void generate_final_assembly() {}