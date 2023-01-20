#include "utilities.h"

void show_error(error_class ec, error_type e, const string& str, ostream& out,
                int line_no) {
    error_count++;

    if (ec == LEXICAL) {
        out << "Error at line# " << line_no << ": ";

        switch (e) {
            case MULTICHAR:
                out << "MULTICHAR_CONST_CHAR " << str << endl;
                break;
            case EMPTY_CHAR:
                out << "EMPTY_CONST_CHAR " << str << endl;
                break;
            case UNFINISHED_CHAR:
                out << "UNFINISHED_CONST_CHAR " << str << endl;
                break;
            case UNRECOGNIZED:
                out << "UNRECOGNIZED CHAR " << str << endl;
                break;
            case TOO_DECIMAL:
                out << "TOO_MANY_DECIMAL_POINTS " << str << endl;
                break;
            case ILL_FORMED:
                out << "ILLFORMED_NUMBER " << str << endl;
                break;
            case INVALID_SUFFIX:
                out << "INVALID_ID_SUFFIX_NUM_PREFIX " << str << endl;
                break;
            case UNFINISHED_STRING:
                out << "UNFINISHED_STRING " << str << endl;
                break;
            case UNFINISHED_COMMENT:
                out << "UNFINISHED_COMMENT " << str << endl;
                break;
            default:
                break;
        }

    } else if (ec == SEMANTIC) {
        // suppressing type error messages
        out << "Line# " << line_no << ": ";

        switch (e) {
            case PARAM_REDEFINITION:
                out << "Redefinition of parameter \'" << str << "\'" << endl;
                break;
            case FUNC_REDEFINITION:
                out << "Redefinition of function \'" << str << "\'" << endl;
                break;
            case VARIABLE_REDEFINITION:
                out << "Redefinition of variable \'" << str << "\'" << endl;
                break;
            case DIFFERENT_REDECLARATION:
                out << "\'" << str
                    << "\' redeclared as different kind of symbol" << endl;
                break;
            case CONFLICTING_TYPE:
                out << "Conflicting types for \'" << str << "\'" << endl;
                break;
            case VOID_TYPE:
                out << "Variable or field ";
                if (str != "") out << "\'" << str << "\' ";
                out << "declared void" << endl;
                break;
            case PARAM_NAMELESS:
                out << "Nameless parameter \'" << str
                    << "\' not allowed in function definition" << endl;
                break;
            case UNDECLARED_VARIABLE:
                out << "Undeclared variable \'" << str << "\'" << endl;
                break;
            case UNDECLARED_FUNCTION:
                out << "Undeclared function \'" << str << "\'" << endl;
                break;
            case UNDEFINED_FUNCTION:
                out << "Undefined function \'" << str << "\'" << endl;
                break;
            case ARRAY_AS_VAR:
                out << "Type mismatch for \'" << str << "\', is an array"
                    << endl;
                break;
            case FUNC_AS_VAR:
                out << "Type mismatch for \'" << str << "\', is a function"
                    << endl;
                break;
            case ARG_TYPE_MISMATCH:
                out << "Type mismatch for argument " << str << endl;
                break;
            case ERROR_AS_ARRAY:
                out << "\'" << str << "\' is not an array" << endl;
                break;
            case INDEX_NOT_INT:
                out << "Array subscript is not an integer" << endl;
                break;
            case MOD_OPERAND:
                out << "Operands of modulus must be integers" << endl;
                break;
            case TOO_MANY_ARGUMENTS:
                out << "Too many arguments to function \'" << str << "\'"
                    << endl;
                break;
            case TOO_FEW_ARGUMENTS:
                out << "Too few arguments to function \'" << str << "\'"
                    << endl;
                break;
            case NOT_A_FUNCTION:
                out << "\'" << str << "\' is not a function" << endl;
                break;
            case VOID_USAGE:
                out << "Void cannot be used in expression" << endl;
                break;
            default:
                break;
        }
    } else if (ec == SYNTAX) {
        out << "Line# " << line_no << ": ";
        out << "Syntax error at ";

        switch (e) {
            case S_PARAM_FUNC_DEFINITION:
                out << "parameter list of function definition" << endl;
                break;
            case S_DECL_VAR_DECLARATION:
                out << "declaration list of variable declaration" << endl;
                break;
            case S_UNIT:
                out << "unit" << endl;
                break;
            case S_EXP_STATEMENT:
                out << "expression of expression statement" << endl;
                break;
            case S_ARG_LIST:
                out << "argument list" << endl;
                break;
            case S_PARAM_NAMELESS:
                out << "nameless parameter" << endl;
                break;
            default:
                break;
        }
    } else if (ec == WARNING) {
        out << "Line# " << line_no << ": ";
        out << "Warning: ";

        switch (e) {
            case FLOAT_TO_INT:
                out << "possible loss of data in assignment of FLOAT to INT"
                    << endl;
                break;
            case MOD_BY_ZERO:
                out << "division by zero" << endl;
                break;
            case DIV_BY_ZERO:
                out << "division by zero" << endl;
                break;
            case BITWISE_FLOAT:
                out << "Operands of bitwise operation should be integers"
                    << endl;
                break;
            case LOGICAL_FLOAT:
                out << "Operands of logical operation should be integers"
                    << endl;
                break;
            default:
                break;
        }
    }
}