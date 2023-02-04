#pragma once
#include <fstream>
#include <string>
using namespace std;

extern ofstream codeout, tempout;
extern int line_count;

void init_icg();
void generate_printing_function();
void generate_final_assembly();
void print_id(const string& s);
string base_indexed_mode(int offset, const string& name);
void generate_code(const string& code, const string& comment = "");