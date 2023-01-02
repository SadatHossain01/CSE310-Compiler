#pragma once

#include <iostream>
#include <string>
using namespace std;

#ifndef UTILITIES_H
#define UTILITIES_H

extern int error_count;
extern int line_count;

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
    DIFFERENT_REDECLARATION,  // originally declared one thing, but now being
                              // declared as another thing (or data type)
    CONFLICTING_TYPE,  // return type mismatch or number of parameters mismatch
                       // or any individual type mismatch
};
enum error_class { LEXICAL, SYNTAX, SEMANTIC };
enum num_type { INTNUM, FLOATNUM };
enum line_type { SINGLE_LINE, MULTILINE };
enum reset_type { CHAR_RESET, STRING_RESET, COMMENT_RESET };

inline void show_error(error_class ec, error_type e, const string& str,
                       ostream& out) {}

#endif