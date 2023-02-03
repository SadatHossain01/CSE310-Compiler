#pragma once
#include <fstream>
#include <string>
using std::ifstream;
using std::ofstream;
using std::string;

extern ofstream codeout, tempout;

void init_icg();
void generate_printing_function();
void generate_final_assembly();