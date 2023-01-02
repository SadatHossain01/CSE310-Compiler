#include "utilities.h"

void show_error(error_class ec, error_type e, const string& str, ostream& out) {
    error_count++;

    if (ec == LEXICAL) {
        out << "Error at line# " << line_count << ": ";

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
                out << "UNRECOGNIZED_CHAR " << str << endl;
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
        out << "Line# " << line_count << ": ";

        switch (e) {
            case PARAM_REDEFINITION:
                out << "Redefinition of parameter \'" << str << "\'" << endl;
                break;
            case FUNC_REDEFINITION:
                out << "Redefinition of function \'" << str << "\'" << endl;
                break;
            case DIFFERENT_REDECLARATION:
                out << "\'" << str
                    << "\' redeclared as different kind of symbol" << endl;
                break;
            case CONFLICTING_TYPE:
                out << "Conflicting types for \'" << str << "\'" << endl;
                break;
            default:
                break;
        }
    } else if (ec == SYNTAX) {
        out << "Line# " << line_count << ": ";
    }
}