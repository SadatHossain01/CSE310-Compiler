#include "utilities.h"

void show_error(error_class ec, error_type e, const string& str, ostream& out,
                int line_no) {
    error_count++;

    if (ec == LEXICAL) {
        out << "Error at line# " << line_no << ": ";

        switch (e) {
            case MULTICHAR:
                out << "MULTICHAR_CONST_CHAR " << str << "\n";
                break;
            case EMPTY_CHAR:
                out << "EMPTY_CONST_CHAR " << str << "\n";
                break;
            case UNFINISHED_CHAR:
                out << "UNFINISHED_CONST_CHAR " << str << "\n";
                break;
            case UNRECOGNIZED:
                out << "UNRECOGNIZED CHAR " << str << "\n";
                break;
            case TOO_DECIMAL:
                out << "TOO_MANY_DECIMAL_POINTS " << str << "\n";
                break;
            case ILL_FORMED:
                out << "ILLFORMED_NUMBER " << str << "\n";
                break;
            case INVALID_SUFFIX:
                out << "INVALID_ID_SUFFIX_NUM_PREFIX " << str << "\n";
                break;
            case UNFINISHED_STRING:
                out << "UNFINISHED_STRING " << str << "\n";
                break;
            case UNFINISHED_COMMENT:
                out << "UNFINISHED_COMMENT " << str << "\n";
                break;
            default:
                break;
        }

    } else if (ec == SEMANTIC) {
        // suppressing type error messages
        out << "Line# " << line_no << ": ";

        switch (e) {
            case PARAM_REDEFINITION:
                out << "Redefinition of parameter \'" << str << "\'"
                    << "\n";
                break;
            case FUNC_REDEFINITION:
                out << "Redefinition of function \'" << str << "\'"
                    << "\n";
                break;
            case VARIABLE_REDEFINITION:
                out << "Redefinition of variable \'" << str << "\'"
                    << "\n";
                break;
            case DIFFERENT_REDECLARATION:
                out << "\'" << str
                    << "\' redeclared as different kind of symbol"
                    << "\n";
                break;
            case CONFLICTING_TYPE:
                out << "Conflicting types for \'" << str << "\'"
                    << "\n";
                break;
            case RETURNING_IN_VOID:
                out << "Function return type has been declared void"
                    << "\n";
                break;
            case VOID_TYPE:
                out << "Variable or field ";
                if (str != "") out << "\'" << str << "\' ";
                out << "declared void"
                    << "\n";
                break;
            case PARAM_NAMELESS:
                out << "Nameless parameter \'" << str
                    << "\' not allowed in function definition"
                    << "\n";
                break;
            case UNDECLARED_VARIABLE:
                out << "Undeclared variable \'" << str << "\'"
                    << "\n";
                break;
            case UNDECLARED_FUNCTION:
                out << "Undeclared function \'" << str << "\'"
                    << "\n";
                break;
            case UNDEFINED_FUNCTION:
                out << "Undefined function \'" << str << "\'"
                    << "\n";
                break;
            case ARRAY_AS_VAR:
                out << "Type mismatch for \'" << str << "\', is an array"
                    << "\n";
                break;
            case FUNC_AS_VAR:
                out << "Type mismatch for \'" << str << "\', is a function"
                    << "\n";
                break;
            case ARG_TYPE_MISMATCH:
                out << "Type mismatch for argument " << str << "\n";
                break;
            case ERROR_AS_ARRAY:
                out << "\'" << str << "\' is not an array"
                    << "\n";
                break;
            case INDEX_NOT_INT:
                out << "Array subscript is not an integer"
                    << "\n";
                break;
            case MOD_OPERAND:
                out << "Operands of modulus must be integers"
                    << "\n";
                break;
            case TOO_MANY_ARGUMENTS:
                out << "Too many arguments to function \'" << str << "\'"
                    << "\n";
                break;
            case TOO_FEW_ARGUMENTS:
                out << "Too few arguments to function \'" << str << "\'"
                    << "\n";
                break;
            case NOT_A_FUNCTION:
                out << "\'" << str << "\' is not a function"
                    << "\n";
                break;
            case VOID_USAGE:
                out << "Void cannot be used in expression"
                    << "\n";
                break;
            default:
                break;
        }
    } else if (ec == SYNTAX) {
        out << "Line# " << line_no << ": ";
        out << "Syntax error at ";

        switch (e) {
            case S_PARAM_FUNC_DEFINITION:
                out << "parameter list of function definition"
                    << "\n";
                break;
            case S_DECL_VAR_DECLARATION:
                out << "declaration list of variable declaration"
                    << "\n";
                break;
            case S_UNIT:
                out << "unit"
                    << "\n";
                break;
            case S_EXP_STATEMENT:
                out << "expression of expression statement"
                    << "\n";
                break;
            case S_ARG_LIST:
                out << "argument list"
                    << "\n";
                break;
            case S_PARAM_NAMELESS:
                out << "nameless parameter"
                    << "\n";
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
                    << "\n";
                break;
            case MOD_BY_ZERO:
                out << "division by zero"
                    << "\n";
                break;
            case DIV_BY_ZERO:
                out << "division by zero"
                    << "\n";
                break;
            case BITWISE_FLOAT:
                out << "Operands of bitwise operation should be integers"
                    << "\n";
                break;
            case LOGICAL_FLOAT:
                out << "Operands of logical operation should be integers"
                    << "\n";
                break;
            default:
                break;
        }
    }
}
SymbolInfo* create_error_token(const string& rule, int syntax_error_line) {
    SymbolInfo* error_token = new SymbolInfo("", "error");
    error_token->set_rule(rule);
    error_token->set_line(syntax_error_line, syntax_error_line);
    error_token->set_terminal(true);
    return error_token;
}
void print_grammar_rule(const string& parent, const string& children) {
    logout << parent << " : " << children << " "
           << "\n";
}
void free_s(SymbolInfo* s) {
    if (s != nullptr) {
        delete s;
        s = nullptr;
    }
}
bool check_type_specifier(const string& ty, const string& name) {
    if (ty == "VOID") {
        show_error(SEMANTIC, VOID_TYPE, name, errorout);
        return false;
    }
    return true;
}
string type_cast(const string& s1, const string& s2) {
    if (s1 == "VOID" || s2 == "VOID" || s1 == "ERROR" || s2 == "ERROR")
        return "ERROR";
    else if (s1 == "FLOAT" || s2 == "FLOAT") return "FLOAT";
    else return "INT";
}
bool is_zero(const string& str) {
    // already guaranteed to be a valid number from lexer, so no need to check
    // that again
    for (char c : str) {
        if (c != '0' && c != 'e' && c != 'E') return false;
    }
    return true;
}
void insert_function(const string& func_name, const string& type_specifier,
                     const vector<Param>& param_list, bool is_definition) {
    SymbolInfo* function =
        new SymbolInfo(func_name, "FUNCTION", type_specifier);
    if (is_definition) function->set_func_type(DEFINITION);
    else {
        function->set_func_type(DECLARATION);
    }
    function->set_param_list(param_list);

    if (function->get_func_type() == DEFINITION) {
        // no parameter can be nameless in a function definition
        for (int i = 0; i < param_list.size(); i++) {
            if (param_list[i].name == "") {
                show_error(SEMANTIC, PARAM_NAMELESS, function->get_name(),
                           errorout);
                free_s(function);
                return;  // returning as any such function is not acceptable
            }
        }
        // just check the types of the parameters
        SymbolInfo* og_func = sym->search(function->get_name(), 'A');
        if (og_func == nullptr) {
            // this is both declaration and definition then
            sym->insert(function);
        } else {
            if (og_func->get_func_type() == NONE) {
                // same name variable already present with this name
                show_error(SEMANTIC, DIFFERENT_REDECLARATION,
                           function->get_name(), errorout);
            } else if (og_func->get_func_type() == DEFINITION) {
                // function definition already exists
                show_error(SEMANTIC, FUNC_REDEFINITION, function->get_name(),
                           errorout);
            }
            // already declaration exists
            else if (og_func->get_data_type() != type_specifier) {
                // return type mismatch
                show_error(SEMANTIC, CONFLICTING_TYPE, function->get_name(),
                           errorout);
            } else if (og_func->get_param_list().size() != param_list.size()) {
                // parameter size mismatch
                show_error(SEMANTIC, CONFLICTING_TYPE, function->get_name(),
                           errorout);
            } else {
                // defintion param type and declaraion param type mismatch check
                vector<Param> og_list = og_func->get_param_list();
                vector<Param> now_list = function->get_param_list();
                for (int i = 0; i < og_list.size(); i++) {
                    if (og_list[i].data_type != now_list[i].data_type) {
                        show_error(SEMANTIC, CONFLICTING_TYPE,
                                   function->get_name(), errorout);
                    }
                }
            }
            og_func->set_func_type(
                DEFINITION);  // set the func type to definition
            free_s(function);
        }
    } else {
        // if it is a function definition, the check is done in lcurls -> LCURL,
        // check there but if prototype, check not done there
        for (int i = 0; i < param_list.size(); i++) {
            for (int j = i + 1; j < param_list.size(); j++) {
                // checking if any two parameters have same name except both
                // being ""
                if (param_list[i].name == "") continue;
                if (param_list[i].name == param_list[j].name) {
                    show_error(SEMANTIC, PARAM_REDEFINITION, param_list[i].name,
                               errorout);
                    free_s(function);
                    return;  // returning as any such function is not acceptable
                }
            }
        }
        // this is just a prototype
        SymbolInfo* og_func = sym->search(function->get_name(), 'A');
        if (og_func == nullptr) {
            // this is both declaration and definition then
            sym->insert(function);
        } else {
            if (og_func->get_func_type() == NONE) {
                // same name variable already present with this name
                show_error(SEMANTIC, DIFFERENT_REDECLARATION,
                           function->get_name(), errorout);
            } else if (og_func->get_func_type() != NONE) {
                // function definition already exists
                show_error(SEMANTIC, FUNC_REDEFINITION, function->get_name(),
                           errorout);
            }
            free_s(function);
        }
    }
}
void insert_symbols(const string& type, const vector<Param>& param_list) {
    string str = "";
    vector<Param> cur_list = param_list;
    for (int i = 0; i < cur_list.size(); i++) {
        str += cur_list[i].name;
        if (i != cur_list.size() - 1) str += ", ";
    }
    bool ok = check_type_specifier(type, str);
    if (ok) {
        for (int i = 0; i < cur_list.size(); i++) {
            // now we will set the data_type of all these symbols to $1
            cur_list[i].data_type = type;
            // cerr << cur_list[i].data_type << " " << cur_list[i].name << "\n";
            SymbolInfo* res = sym->search(cur_list[i].name, 'C');
            if (res == nullptr) {
                SymbolInfo* new_sym = new SymbolInfo(cur_list[i].name, "ID",
                                                     cur_list[i].data_type);
                if (cur_list[i].is_array) new_sym->set_array(true);
                sym->insert(new_sym);
            } else if (res->get_data_type() != cur_list[i].data_type) {
                // cerr << "Previous: " << res->get_data_type() << " current: "
                // << cur_list[i].data_type << " " << cur_list[i].name << "
                // line: " << line_count << "\n";
                show_error(SEMANTIC, CONFLICTING_TYPE, cur_list[i].name,
                           errorout);
            } else {
                show_error(SEMANTIC, VARIABLE_REDEFINITION, cur_list[i].name,
                           errorout);
            }
        }
    }
}