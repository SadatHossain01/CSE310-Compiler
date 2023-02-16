#pragma once

#include <iostream>
#include <string>

#include "icg_util.h"
#include "symbol_table.h"

using std::endl;
using std::ostream;
using std::string;

extern int error_count;
extern int line_count, current_offset;
extern ofstream treeout, errorout, logout, codeout, tempout;
extern SymbolTable* sym;

enum error_type {
    MULTICHAR,
    EMPTY_CHAR,
    UNFINISHED_CHAR,
    UNRECOGNIZED,
    TOO_DECIMAL,
    ILL_FORMED,
    INVALID_SUFFIX,
    UNFINISHED_STRING,
    UNFINISHED_COMMENT,
    PARAM_REDEFINITION,
    FUNC_REDEFINITION,
    VARIABLE_REDEFINITION,
    DIFFERENT_REDECLARATION,  // originally declared one thing, but now being
                              // declared as another thing (or data type)
    CONFLICTING_TYPE,         // number of parameters mismatch
                              // or any individual type mismatch
    RETURNING_IN_VOID,
    VOID_TYPE,
    PARAM_NAMELESS,
    UNDECLARED_VARIABLE,
    UNDECLARED_FUNCTION,
    ARRAY_AS_VAR,
    FUNC_AS_VAR,
    ERROR_AS_ARRAY,
    ARG_TYPE_MISMATCH,
    INDEX_NOT_INT,
    VOID_USAGE,
    MOD_OPERAND,
    NOT_A_FUNCTION,
    UNDEFINED_FUNCTION,
    TOO_MANY_ARGUMENTS,
    TOO_FEW_ARGUMENTS,
    BITWISE_FLOAT,
    LOGICAL_FLOAT,
    S_PARAM_FUNC_DEFINITION,
    S_DECL_VAR_DECLARATION,
    S_UNIT,
    S_EXP_STATEMENT,
    S_ARG_LIST,
    S_PARAM_NAMELESS,
    FLOAT_TO_INT,
    MOD_BY_ZERO,
    DIV_BY_ZERO,
};
enum error_class { LEXICAL, SYNTAX, SEMANTIC, WARNING };
enum num_type { INTNUM, FLOATNUM };
enum line_type { SINGLE_LINE, MULTILINE };
enum reset_type { CHAR_RESET, STRING_RESET, COMMENT_RESET };

void show_error(error_class, error_type, const string&, ostream&, int line_no = line_count);
SymbolInfo* create_error_token(const string&, int);
void print_grammar_rule(const string&, const string&);
void free_s(SymbolInfo*);
bool check_type_specifier(const string&, const string&);
string type_cast(const string&, const string&);
bool is_zero(const string&);
void insert_function(const string&, const string&, const vector<Param>&, bool);
void insert_symbols(const string&, const vector<Param>&, bool global_scope);