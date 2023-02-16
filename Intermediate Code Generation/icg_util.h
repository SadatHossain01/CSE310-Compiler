#pragma once
#include <fstream>
#include <string>
#include <unordered_map>

#include "symbol_table.h"
using namespace std;

extern ofstream codeout, tempout;
extern int line_count, current_offset, label_count, printed_line_count;
extern unordered_map<int, int> label_map;

void init_icg();
void generate_printing_function();
void generate_final_assembly();
void print_id(const string& s);
void push_to_stack(const string& name);
string get_variable_address(SymbolInfo* sym);
string get_variable_address(const string& name, const int offset);
void generate_code(const string& code, const string& comment = "");
void generate_incop_code(SymbolInfo* sym, const string& op);
void generate_logicop_code(const string& op);
void generate_addop_code(const string& op);
void generate_mulop_code(const string& op);
void generate_relop_code(const string& op);
vector<int> merge(const vector<int>& v1, const vector<int>& v2);
void backpatch(const vector<int>& v, int label);