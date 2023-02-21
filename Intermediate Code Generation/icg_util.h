#pragma once
#include <algorithm>
#include <fstream>
#include <map>
#include <string>
#include <unordered_set>

#include "symbol_table.h"
using namespace std;

extern ofstream codeout, tempout;
extern int line_count, current_offset, label_count, printed_line_count, temp_file_lc;
extern map<int, string> label_map;
extern unordered_set<string> useful_labels;

void init_icg();
void generate_printing_function();
void generate_final_assembly();
void print_id(const string& s);
void push_to_stack(const string& name);
void pop_from_stack(const string& name);
string get_variable_address(SymbolInfo* sym);
string get_variable_address(const string& name, const int offset);
void generate_code(const string& code, const string& comment = "", bool tab = true);
void generate_incop_code(SymbolInfo* sym, const string& op);
void generate_logicop_code(const string& op);
void generate_addop_code(const string& op);
void generate_mulop_code(const string& op);
void generate_relop_code(const string& op, SymbolInfo* sym);
vector<int> merge(const vector<int>& v1, const vector<int>& v2);
void backpatch(const vector<int>& v, string label);
void print_label(string label);
void print_label(int label);
void generate_code_for_unary_boolean(SymbolInfo* exp);
string trim(const string& trim);
void optimize_code();
vector<string> get_operands(const string& line);
void remove_unreachable_code();
void init_function(const string& func_name);
void return_from_function(const string& func_name, int number_of_args);