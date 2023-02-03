#pragma once
#include <fstream>
using std::ofstream;

extern ofstream codeout, tempout;

void init_icg();
void generate_printing_function();
void generate_final_assembly();