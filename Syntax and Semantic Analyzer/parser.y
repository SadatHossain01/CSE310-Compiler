%{
#include <iostream>
#include <cstdlib>
#include <cstring>
#include <string>
#include <cmath>
#include <vector>
#include <cassert>
#include "utilities.h"
#include "symbol_table.h"

using namespace std;

#define BUCKET_SIZE 11

extern int line_count;
extern int error_count;
int syntax_error_line;
SymbolTable *sym;
extern FILE* yyin;
vector<Param> current_function_parameters;

ofstream treeout, errorout, logout;

void yyerror(const string& s) {
	logout << "Error at line no " << line_count << " : syntax error" << endl;
	syntax_error_line = line_count;
}
int yyparse(void);
int yylex(void);

inline void print_grammar_rule(const string& parent, const string& children) {
	logout << parent << " : " << children << " " << endl;
}

inline void free_s(SymbolInfo* s)	{
	if (s != nullptr) {
		delete s;
		s = nullptr;
	}
}

inline bool check_type_specifier(const string& ty, const string& name) {
	if (ty == "VOID") {
		show_error(SEMANTIC, VOID_TYPE, name, errorout);
		return false;
	}
	return true;
}

inline string type_cast(const string& s1, const string& s2) {
	if (s1 == "VOID" || s2 == "VOID" || s1 == "ERROR" || s2 == "ERROR") return "ERROR";
	else if (s1 == "FLOAT" || s2 == "FLOAT") return "FLOAT";
	else return "INT";
}

inline bool is_zero(const string& str) {
	// already guaranteed to be a valid number from lexer, so no need to check that again
	for (char c : str) {
		if (c != '0' && c != 'e' && c != 'E') return false;
	}
	return true;
}

void insert_function(const string& func_name, const string& type_specifier, const vector<Param>& param_list, bool is_definition) {
	if (is_definition) {
		current_function_parameters.clear();
		current_function_parameters = param_list;
	}
	SymbolInfo* function = new SymbolInfo(func_name, "FUNCTION", type_specifier);
	if (is_definition) function->set_func_type(DEFINITION);
	else {
		function->set_func_type(DECLARATION);
	}
	function->set_param_list(param_list);

	if (function->get_func_type() == DEFINITION) {
		// no parameter can be nameless in a function definition
		for (int i = 0; i < param_list.size(); i++) {
			if (param_list[i].name == "") {
				show_error(SEMANTIC, PARAM_NAMELESS, function->get_name(), errorout);
				free_s(function);
				return; // returning as any such function is not acceptable
			}
		}
		// just check the types of the parameters
		SymbolInfo* og_func = sym->search(function->get_name(), 'A');
		if (og_func == nullptr) {
			// this is both declaration and definition then
			sym->insert(function);
		}
		else {
			if (og_func->get_func_type() == NONE) {
				// same name variable already present with this name
				show_error(SEMANTIC, DIFFERENT_REDECLARATION, function->get_name(), errorout);
			}
			else if (og_func->get_func_type() == DEFINITION) {
				// function definition already exists
				show_error(SEMANTIC, FUNC_REDEFINITION, function->get_name(), errorout);
			}
			// already declaration exists
			else if (og_func->get_data_type() != type_specifier) {
				// return type mismatch
				show_error(SEMANTIC, CONFLICTING_TYPE, function->get_name(), errorout);
			}
			else if (og_func->get_param_list().size() != param_list.size()) {
				// parameter size mismatch
				show_error(SEMANTIC, CONFLICTING_TYPE, function->get_name(), errorout);
			}
			else {
				// defintion param type and declaraion param type mismatch check
				vector<Param> og_list = og_func->get_param_list();
				vector<Param> now_list = function->get_param_list();
				for (int i = 0; i < og_list.size(); i++) {
					if (og_list[i].data_type != now_list[i].data_type) {
						show_error(SEMANTIC, CONFLICTING_TYPE, function->get_name(), errorout);
					}
				}
			}
			og_func->set_func_type(DEFINITION); // set the func type to definition
			free_s(function);
		}
	}
	else {
		// if it is a function definition, the check is done in lcurls -> LCURL, check there
		// but if prototype, check not done there
		for (int i = 0; i < param_list.size(); i++) {
			for (int j = i + 1; j < param_list.size(); j++) {
				// checking if any two parameters have same name except both being ""
				if (param_list[i].name == "") continue;
				if (param_list[i].name == param_list[j].name) {
					show_error(SEMANTIC, PARAM_REDEFINITION, param_list[i].name, errorout);
					free_s(function);
					return; // returning as any such function is not acceptable
				}
			}
		}
		// this is just a prototype
		SymbolInfo* og_func = sym->search(function->get_name(), 'A');
		if (og_func == nullptr) {
			// this is both declaration and definition then
			sym->insert(function);
		}
		else {
			if (og_func->get_func_type() == NONE) {
				// same name variable already present with this name
				show_error(SEMANTIC, DIFFERENT_REDECLARATION, function->get_name(), errorout);
			}
			else if (og_func->get_func_type() != NONE) {
				// function definition already exists
				show_error(SEMANTIC, FUNC_REDEFINITION, function->get_name(), errorout);
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
			// cerr << cur_list[i].data_type << " " << cur_list[i].name << endl;
			SymbolInfo* res = sym->search(cur_list[i].name, 'C');
			if (res == nullptr) {
				SymbolInfo* new_sym = new SymbolInfo(cur_list[i].name, "ID", cur_list[i].data_type);
				if (cur_list[i].is_array) new_sym->set_array(true);
				sym->insert(new_sym);
			}
			else if (res->get_data_type() != cur_list[i].data_type) {
				// cerr << "Previous: " << res->get_data_type() << " current: " << cur_list[i].data_type << " " << cur_list[i].name << " line: " << line_count << endl; 
				show_error(SEMANTIC, CONFLICTING_TYPE, cur_list[i].name, errorout);
			}
			else {
				show_error(SEMANTIC, VARIABLE_REDEFINITION, cur_list[i].name, errorout);
			}
		}
	}
}

%}

%nonassoc THEN
%nonassoc ELSE

%error-verbose

%union {
	SymbolInfo* symbol_info;
}

%destructor {  
	// handles error tokens and start symbol
	$$->delete_tree();
	free_s($$);
} <symbol_info>

%token <symbol_info> IF ELSE FOR WHILE DO BREAK RETURN SWITCH CASE DEFAULT CONTINUE PRINTLN ADDOP INCOP DECOP RELOP ASSIGNOP LOGICOP BITOP NOT LPAREN RPAREN LCURL RCURL LSQUARE RSQUARE COMMA SEMICOLON INT CHAR FLOAT DOUBLE VOID
%token <symbol_info> CONST_INT CONST_FLOAT ID MULOP
%type <symbol_info> start program unit var_declaration func_declaration func_definition type_specifier parameter_list compound_statement statements declaration_list statement expression expression_statement logic_expression rel_expression simple_expression term unary_expression factor variable argument_list arguments lcurls

%%

start : program {
		print_grammar_rule("start", "program");
		$$ = new SymbolInfo("", "start");
		$$->set_rule("start : program");
		$$->add_child($1);
		$$->print_tree_node(treeout);
		// the following is being handled in %destructor
		// $$->delete_tree();
		// free_s($$);
	}
	;

program : program unit {
		print_grammar_rule("program", "program unit");
		$$ = new SymbolInfo("", "program");	
		$$->set_rule("program : program unit");
		$$->add_child($1); $$->add_child($2);
	}
	| unit {
		print_grammar_rule("program", "unit");
		$$ = new SymbolInfo("", "program");
		$$->set_rule("program : unit");
		$$->add_child($1);
	}
	;
	
unit : var_declaration {
		print_grammar_rule("unit", "var_declaration");
		$$ = new SymbolInfo("", "unit");
		$$->set_rule("unit : var_declaration");
		$$->add_child($1);
	}
    | func_declaration {
		print_grammar_rule("unit", "func_declaration");
		$$ = new SymbolInfo("", "unit");
		$$->set_rule("unit : func_declaration");
		$$->add_child($1);
	}
    | func_definition {
		print_grammar_rule("unit", "func_definition");
		$$ = new SymbolInfo("", "unit");
		$$->set_rule("unit : func_definition");
		$$->add_child($1);
	}
	| error {
		show_error(SYNTAX, S_UNIT, "", errorout);
		$$ = new SymbolInfo("", "unit");
	}
    ;
     
func_declaration : type_specifier ID LPAREN parameter_list RPAREN SEMICOLON {
		print_grammar_rule("func_declaration", "type_specifier ID LPAREN parameter_list RPAREN SEMICOLON");
		current_function_parameters.clear(); // resetting for this function
		$$ = new SymbolInfo("", "func_declaration");
		insert_function($2->get_name(), $1->get_data_type(), $4->get_param_list(), false);
		$$->set_rule("func_declaration : type_specifier ID LPAREN parameter_list RPAREN SEMICOLON");
		$$->add_child($1); $$->add_child($2); $$->add_child($3); $$->add_child($4); $$->add_child($5); $$->add_child($6);
	}
	| type_specifier ID LPAREN error RPAREN SEMICOLON {
		print_grammar_rule("func_declaration", "type_specifier ID LPAREN RPAREN SEMICOLON");
		current_function_parameters.clear();
		$$ = new SymbolInfo("", "func_declaration");
		insert_function($2->get_name(), $1->get_data_type(), {}, false);
		$$->set_rule("func_declaration : type_specifier ID LPAREN RPAREN SEMICOLON");
		$$->add_child($1); $$->add_child($2); $$->add_child($3); $$->add_child($5); $$->add_child($6);
	}
	| type_specifier ID LPAREN RPAREN SEMICOLON {
		print_grammar_rule("func_declaration", "type_specifier ID LPAREN RPAREN SEMICOLON");
		current_function_parameters.clear();
		$$ = new SymbolInfo("", "func_declaration");
		insert_function($2->get_name(), $1->get_data_type(), {}, false);
		$$->set_rule("func_declaration : type_specifier ID LPAREN RPAREN SEMICOLON");
		$$->add_child($1); $$->add_child($2); $$->add_child($3); $$->add_child($4); $$->add_child($5);
	}
	;
	 
func_definition : type_specifier ID LPAREN parameter_list RPAREN { insert_function($2->get_name(), $1->get_data_type(), $4->get_param_list(), true); } compound_statement {
		print_grammar_rule("func_definition", "type_specifier ID LPAREN parameter_list RPAREN compound_statement");
		$$ = new SymbolInfo("", "func_definition");
		$$->set_rule("func_definition : type_specifier ID LPAREN parameter_list RPAREN compound_statement");
		// notice that compound_statement is not $6, it is $7
		$$->add_child($1); $$->add_child($2); $$->add_child($3); $$->add_child($4); $$->add_child($5); $$->add_child($7);
	}
	| type_specifier ID LPAREN error RPAREN compound_statement {
		// not inserting the function if any error occurs in parameter list
		// print_grammar_rule("func_definition", "type_specifier ID LPAREN parameter_list RPAREN compound_statement");
		$$ = new SymbolInfo("", "func_definition");
		show_error(SYNTAX, S_PARAM_FUNC_DEFINITION, "", errorout, syntax_error_line);
		$$->set_rule("func_definition : type_specifier ID LPAREN RPAREN compound_statement");
		$$->add_child($1); $$->add_child($2); $$->add_child($3); $$->add_child($5); $$->add_child($6);
	}
	| type_specifier ID LPAREN RPAREN { insert_function($2->get_name(), $1->get_data_type(), {}, true); } compound_statement {
		print_grammar_rule("func_definition", "type_specifier ID LPAREN RPAREN compound_statement");
		$$ = new SymbolInfo("", "func_definition");
		$$->set_rule("func_definition : type_specifier ID LPAREN RPAREN compound_statement");
		$$->add_child($1); $$->add_child($2); $$->add_child($3); $$->add_child($4); $$->add_child($6);
	}
	;				

parameter_list : parameter_list COMMA type_specifier ID {
		print_grammar_rule("parameter_list", "parameter_list COMMA type_specifier ID");
		$$ = new SymbolInfo("", "parameter_list");
		$$->set_param_list($1->get_param_list());
		$$->add_param($4->get_name(), $3->get_data_type());
		check_type_specifier($3->get_data_type(), $4->get_name());
		current_function_parameters = $$->get_param_list();
		$$->set_rule("parameter_list : parameter_list COMMA type_specifier ID");
		$$->add_child($1); $$->add_child($2); $$->add_child($3); $$->add_child($4);
	}
	| parameter_list COMMA type_specifier {
		print_grammar_rule("parameter_list", "parameter_list COMMA type_specifier");
		$$ = new SymbolInfo("", "parameter_list");
		$$->set_param_list($1->get_param_list());
		$$->add_param("", $3->get_data_type());
		check_type_specifier($3->get_data_type(), "");
		current_function_parameters = $$->get_param_list();
		$$->set_rule("parameter_list : parameter_list COMMA type_specifier");
		$$->add_child($1); $$->add_child($2); $$->add_child($3);
	}
	| type_specifier ID {
		print_grammar_rule("parameter_list", "type_specifier ID");
		$$ = new SymbolInfo("", "parameter_list");
		$$->add_param($2->get_name(), $1->get_data_type());
		check_type_specifier($1->get_data_type(), $2->get_name());
		current_function_parameters = $$->get_param_list();
		$$->set_rule("parameter_list : type_specifier ID");
		$$->add_child($1); $$->add_child($2);
	}
	| type_specifier {
		print_grammar_rule("parameter_list", "type_specifier");
		$$ = new SymbolInfo("", "parameter_list");
		$$->add_param("", $1->get_data_type());
		check_type_specifier($1->get_data_type(), "");
		current_function_parameters = $$->get_param_list();
		$$->set_rule("parameter_list : type_specifier");
		$$->add_child($1);
	}
	;
	
compound_statement : lcurls statements RCURL {
		print_grammar_rule("compound_statement", "LCURL statements RCURL");
		$$ = new SymbolInfo("", "compound_statement");
		sym->print('A', logout);
		sym->exit_scope();
		$$->set_rule("compound_statement : LCURL statements RCURL");
		$$->add_child($1); $$->add_child($2); $$->add_child($3);
	}
	| lcurls error RCURL {
		print_grammar_rule("compound_statement", "LCURL RCURL");
		$$ = new SymbolInfo("", "compound_statement");
		sym->print('A', logout);
		sym->exit_scope();
		$$->set_rule("compound_statement : LCURL RCURL");
		$$->add_child($1); $$->add_child($3);
	}
	| lcurls RCURL {
		print_grammar_rule("compound_statement", "LCURL RCURL");
		$$ = new SymbolInfo("", "compound_statement");
		sym->print('A', logout);
		sym->exit_scope();
		$$->set_rule("compound_statement : LCURL RCURL");
		$$->add_child($1); $$->add_child($2);
	}
	;
 		    
var_declaration : type_specifier declaration_list SEMICOLON {
		print_grammar_rule("var_declaration", "type_specifier declaration_list SEMICOLON");
		$$ = new SymbolInfo("", "var_declaration", $1->get_data_type());
		insert_symbols($1->get_data_type(), $2->get_param_list());
		$$->set_rule("var_declaration : type_specifier declaration_list SEMICOLON");
		$$->add_child($1); $$->add_child($2); $$->add_child($3);
	}
	| type_specifier declaration_list error SEMICOLON {
		print_grammar_rule("var_declaration", "type_specifier declaration_list SEMICOLON");	
		$$ = new SymbolInfo("", "var_declaration", $1->get_data_type());
		insert_symbols($1->get_data_type(), $2->get_param_list());
		show_error(SYNTAX, S_DECL_VAR_DECLARATION, "", errorout, syntax_error_line);
		$$->set_rule("var_declaration : type_specifier declaration_list SEMICOLON");
		$$->add_child($1); $$->add_child($2); $$->add_child($4);

	}
	| type_specifier error SEMICOLON {
		print_grammar_rule("var_declaration", "type_specifier declaration_list SEMICOLON");
		$$ = new SymbolInfo("", "var_declaration", $1->get_data_type());
		show_error(SYNTAX, S_DECL_VAR_DECLARATION, "", errorout, syntax_error_line);
		$$->set_rule("var_declaration : type_specifier SEMICOLON");
		$$->add_child($1); $$->add_child($3);
	}
	;
 		 
type_specifier : INT {
		print_grammar_rule("type_specifier", "INT");
		$$ = new SymbolInfo("", "type_specifier", "int");
		$$->set_rule("type_specifier : INT");
		$$->add_child($1);
	}
	| FLOAT {
		print_grammar_rule("type_specifier", "FLOAT");
		$$ = new SymbolInfo("", "type_specifier", "float");
		$$->set_rule("type_specifier : FLOAT");
		$$->add_child($1);
	}
	| VOID {
		print_grammar_rule("type_specifier", "VOID");
		$$ = new SymbolInfo("", "type_specifier", "void");
		$$->set_rule("type_specifier : VOID");
		$$->add_child($1);
	}
	;
 		
declaration_list : declaration_list COMMA ID {
		print_grammar_rule("declaration_list", "declaration_list COMMA ID");
		$$ = new SymbolInfo("", "declaration_list");
		$$->set_param_list($1->get_param_list());
		$$->add_param($3->get_name(), "");
		$$->set_rule("declaration_list : declaration_list COMMA ID");
		$$->add_child($1); $$->add_child($2); $$->add_child($3);
	}
	| declaration_list COMMA ID LSQUARE CONST_INT RSQUARE {
		print_grammar_rule("declaration_list", "declaration_list COMMA ID LSQUARE CONST_INT RSQUARE");
		$$ = new SymbolInfo("", "declaration_list");
		$$->set_param_list($1->get_param_list());
		$$->add_param($3->get_name(), "ID", true);
		$$->set_rule("declaration_list : declaration_list COMMA ID LSQUARE CONST_INT RSQUARE");
		$$->add_child($1); $$->add_child($2); $$->add_child($3); $$->add_child($4); $$->add_child($5); $$->add_child($6);
	}
	| ID {
		print_grammar_rule("declaration_list", "ID");
		$$ = new SymbolInfo("", "declaration_list");
		$$->add_param($1->get_name(), "ID");
		$$->set_rule("declaration_list : ID");
		$$->add_child($1);
	}
	| ID LSQUARE CONST_INT RSQUARE {
		print_grammar_rule("declaration_list", "ID LSQUARE CONST_INT RSQUARE");
		$$ = new SymbolInfo("", "declaration_list");
		$$->add_param($1->get_name(), "ID", true);
		$$->set_rule("declaration_list : ID LSQUARE CONST_INT RSQUARE");
		$$->add_child($1); $$->add_child($2); $$->add_child($3); $$->add_child($4);
	}
	;
 		  
statements : statement {
		print_grammar_rule("statements", "statement");
		$$ = new SymbolInfo($1->get_name(), "statements");
		$$->set_rule("statements : statement");
		$$->add_child($1);
	}
	| statements statement {
		print_grammar_rule("statements", "statements statement");
		$$ = new SymbolInfo($1->get_name(), "statements");
		$$->set_rule("statements : statements statement");
		$$->add_child($1); $$->add_child($2);
	}
	;
	   
statement : var_declaration {
		print_grammar_rule("statement", "var_declaration");
		$$ = new SymbolInfo($1->get_name(), "statement", $1->get_data_type());
		$$->set_rule("statement : var_declaration");
		$$->add_child($1);
	}
	| expression_statement {
		print_grammar_rule("statement", "expression_statement");
		$$ = new SymbolInfo($1->get_name(), "statement", $1->get_data_type());
		$$->set_rule("statement : expression_statement");
		$$->add_child($1);
	}
	| compound_statement {
		print_grammar_rule("statement", "compound_statement");
		$$ = new SymbolInfo($1->get_name(), "statement", $1->get_data_type());
		$$->set_rule("statement : compound_statement");
		$$->add_child($1);
	}
	| FOR LPAREN expression_statement expression_statement expression RPAREN statement {
		print_grammar_rule("statement", "FOR LPAREN expression_statement expression_statement expression RPAREN statement");
		$$ = new SymbolInfo("", "statement");
		$$->set_rule("statement : FOR LPAREN expression_statement expression_statement expression RPAREN statement");
		$$->add_child($1); $$->add_child($2); $$->add_child($3); $$->add_child($4); $$->add_child($5); $$->add_child($6); $$->add_child($7);
	}
	| IF LPAREN expression RPAREN statement %prec THEN {
		// use the precedence of THEN here
		print_grammar_rule("statement", "IF LPAREN expression RPAREN statement %prec THEN");
		$$ = new SymbolInfo("", "statement");
		$$->set_rule("statement : IF LPAREN expression RPAREN statement");
		$$->add_child($1); $$->add_child($2); $$->add_child($3); $$->add_child($4); $$->add_child($5);
	}
	| IF LPAREN expression RPAREN statement ELSE statement {
		print_grammar_rule("statement", "IF LPAREN expression RPAREN statement ELSE statement");
		$$ = new SymbolInfo("", "statement");
		$$->set_rule("statement : IF LPAREN expression RPAREN statement ELSE statement");
		$$->add_child($1); $$->add_child($2); $$->add_child($3); $$->add_child($4); $$->add_child($5); $$->add_child($6); $$->add_child($7);
	}
	| WHILE LPAREN expression RPAREN statement {
		print_grammar_rule("statement", "WHILE LPAREN expression RPAREN statement");
		$$ = new SymbolInfo("", "statement");
		$$->set_rule("statement : WHILE LPAREN expression RPAREN statement");
		$$->add_child($1); $$->add_child($2); $$->add_child($3); $$->add_child($4); $$->add_child($5);
	}
	| PRINTLN LPAREN ID RPAREN SEMICOLON {
		print_grammar_rule("statement", "PRINTLN LPAREN ID RPAREN SEMICOLON");
		$$ = new SymbolInfo("", "statement");
		if (sym->search($3->get_name(), 'A') == nullptr) {
			show_error(SEMANTIC, UNDECLARED_VARIABLE, $3->get_name(), errorout);
		}
		$$->set_rule("statement : PRINTLN LPAREN ID RPAREN SEMICOLON");
		$$->add_child($1); $$->add_child($2); $$->add_child($3); $$->add_child($4); $$->add_child($5);
	}
	| RETURN expression SEMICOLON {
		print_grammar_rule("statement", "RETURN expression SEMICOLON");
		$$ = new SymbolInfo("", "statement");
		$$->set_rule("statement : RETURN expression SEMICOLON");
		$$->add_child($1); $$->add_child($2); $$->add_child($3);
		// add return type check here
	}
	;
	  
expression_statement : SEMICOLON {
		print_grammar_rule("expression_statement", "SEMICOLON");
		$$ = new SymbolInfo("", "expression_statement");
		$$->set_rule("expression_statement : SEMICOLON");
		$$->add_child($1);
	}
	| expression SEMICOLON {
		print_grammar_rule("expression_statement", "expression SEMICOLON");
		$$ = new SymbolInfo("", "expression_statement");
		$$->set_data_type($1->get_data_type()); // result of an expression will have a certain data type, won't it?
		$$->set_rule("expression_statement : expression SEMICOLON");
		$$->add_child($1); $$->add_child($2);
	}
	| error SEMICOLON {
		show_error(SYNTAX, S_EXP_STATEMENT, "", errorout, syntax_error_line);
		$$ = new SymbolInfo("", "expression_statement");
		free_s($2);
	}
	;
	  
variable : ID {
		print_grammar_rule("variable", "ID");
		$$ = new SymbolInfo($1->get_name(), "VARIABLE", $1->get_data_type());
		
		SymbolInfo* res = sym->search($1->get_name(), 'A');
		if (res == nullptr) {
			show_error(SEMANTIC, UNDECLARED_VARIABLE, $1->get_name(), errorout);
		}
		else {
			$$->set_data_type(res->get_data_type());
			$$->set_array(res->is_array());
		}
		$$->set_rule("variable : ID");
		$$->add_child($1);
	}	
	| ID LSQUARE expression RSQUARE {
		// it has to be an array now
		print_grammar_rule("variable", "ID LSQUARE expression RSQUARE");
		$$ = new SymbolInfo($1->get_name(), "VARIABLE", $1->get_data_type());
		
		SymbolInfo* res = sym->search($1->get_name(), 'A');
		if (res == nullptr) {
			show_error(SEMANTIC, UNDECLARED_VARIABLE, $1->get_name(), errorout);
		}
		else if (!res->is_array()) {
			// declared as a normal variable, but used like an array, so error
			show_error(SEMANTIC, ERROR_AS_ARRAY, $1->get_name(), errorout);
		}
		else if ($3->get_data_type() != "INT") {
			// array index is not an integer, so error
			show_error(SEMANTIC, INDEX_NOT_INT, $1->get_name(), errorout);
		}
		else {
			$$->set_data_type(res->get_data_type());
			$$->set_array(false); // if a is an int array, a[5] is also an int, but not an array
		}
		$$->set_rule("variable : ID LSQUARE expression RSQUARE");
		$$->add_child($1); $$->add_child($2); $$->add_child($3); $$->add_child($4);
	}
	;
	 
expression : logic_expression {
		print_grammar_rule("expression", "logic_expression");
		$$ = new SymbolInfo($1->get_name(), "expression", $1->get_data_type());
		$$->set_array($1->is_array());
		$$->set_rule("expression : logic_expression");
		$$->add_child($1);
	}	
	| variable ASSIGNOP logic_expression {
		print_grammar_rule("expression", "variable ASSIGNOP logic_expression");
		$$ = new SymbolInfo("", "expression");
		if ($1->is_array() && !$3->is_array()) {
			show_error(SEMANTIC, ARRAY_AS_VAR, $1->get_name(), errorout);
		}
		else if ($1->get_data_type() == "VOID" || $3->get_data_type() == "VOID") {
			show_error(SEMANTIC, VOID_USAGE, "", errorout);
			$$->set_data_type("ERROR");
		}
		else if ($1->get_data_type() == "ERROR" || $3->get_data_type() == "ERROR") {
			// show_error(SEMANTIC, TYPE_ERROR, "", errorout);
			$$->set_data_type("ERROR");
		}
		else if ($1->get_data_type() == "INT") {
			if ($3->get_data_type() == "FLOAT") {
				show_error(WARNING, FLOAT_TO_INT, "", errorout);
			}
			$$->set_data_type("INT");
		}
		else {
			$$->set_data_type("FLOAT");
		}
		$$->set_rule("expression : variable ASSIGNOP logic_expression");
		$$->add_child($1); $$->add_child($2); $$->add_child($3);
	}	
	;
			
logic_expression : rel_expression {
		print_grammar_rule("logic_expression", "rel_expression");
		$$ = new SymbolInfo($1->get_name(), "logic_expression", $1->get_data_type());
		$$->set_array($1->is_array());
		$$->set_rule("logic_expression : rel_expression");
		$$->add_child($1);
	}
	| rel_expression LOGICOP rel_expression {
		print_grammar_rule("logic_expression", "rel_expression LOGICOP rel_expression");
		$$ = new SymbolInfo("", "logic_expression");
		if ($1->get_data_type() == "VOID" || $3->get_data_type() == "VOID") {
			show_error(SEMANTIC, VOID_USAGE, "", errorout);
			$$->set_data_type("ERROR");
		}
		else if ($1->get_data_type() == "ERROR" || $3->get_data_type() == "ERROR") {
			// show_error(SEMANTIC, TYPE_ERROR, "", errorout);
			$$->set_data_type("ERROR");
		}
		else if ($1->get_data_type() == "FLOAT" || $3->get_data_type() == "FLOAT") {
			show_error(WARNING, LOGICAL_FLOAT, "", errorout);
			$$->set_data_type("INT");
		}
		else {
			$$->set_data_type("INT");
		}
		$$->set_rule("logic_expression : rel_expression LOGICOP rel_expression");
		$$->add_child($1); $$->add_child($2); $$->add_child($3);
	}
	;
			
rel_expression : simple_expression {
		print_grammar_rule("rel_expression", "simple_expression");
		$$ = new SymbolInfo($1->get_name(), "rel_expression", $1->get_data_type());
		$$->set_array($1->is_array()); // will need in function argument type checking
		$$->set_rule("rel_expression : simple_expression");
		$$->add_child($1);
	}
	| simple_expression RELOP simple_expression {
		print_grammar_rule("rel_expression", "simple_expression RELOP simple_expression");
		$$ = new SymbolInfo("", "rel_expression");
		if ($1->get_data_type() == "VOID" || $3->get_data_type() == "VOID") {
			show_error(SEMANTIC, VOID_USAGE, "", errorout);
			$$->set_data_type("ERROR");
		}
		else {
			$$->set_data_type("INT"); // result of any comparison should be boolean in fact
		}
		$$->set_rule("rel_expression : simple_expression RELOP simple_expression");
		$$->add_child($1); $$->add_child($2); $$->add_child($3);
	}	
	;
				
simple_expression : term {
		print_grammar_rule("simple_expression", "term");
		$$ = new SymbolInfo($1->get_name(), "simple_expression", $1->get_data_type());
		$$->set_array($1->is_array());
		$$->set_rule("simple_expression : term");
		$$->add_child($1);
	}
	| simple_expression ADDOP term {
		print_grammar_rule("simple_expression", "simple_expression ADDOP term");
		$$ = new SymbolInfo("", "simple_expression");
		if ($1->get_data_type() == "VOID" || $3->get_data_type() == "VOID") {
			show_error(SEMANTIC, VOID_USAGE, "", errorout);
		}
		$$->set_data_type(type_cast($1->get_data_type(), $3->get_data_type()));
		$$->set_rule("simple_expression : simple_expression ADDOP term");
		$$->add_child($1); $$->add_child($2); $$->add_child($3);
	}
	;
					
term : unary_expression {
		print_grammar_rule("term", "unary_expression");
		$$ = new SymbolInfo($1->get_name(), "term", $1->get_data_type());
		$$->set_array($1->is_array());
		$$->set_rule("term : unary_expression");
		$$->add_child($1);
	}
	| term MULOP unary_expression {
		print_grammar_rule("term", "term MULOP unary_expression");
		$$ = new SymbolInfo("", "term");
		if ($1->get_data_type() == "VOID" || $3->get_data_type() == "VOID") {
			show_error(SEMANTIC, VOID_USAGE, "", errorout);
			$$->set_data_type("ERROR");
		}
		else if ($1->get_data_type() == "ERROR" || $3->get_data_type() == "ERROR") {
			// show_error(SEMANTIC, TYPE_ERROR, "", errorout);
			$$->set_data_type("ERROR");
		}
		else if ($2->get_name() == "%") {
			if ($1->get_data_type() == "FLOAT" || $3->get_data_type() == "FLOAT") {
				show_error(SEMANTIC, MOD_OPERAND, "", errorout);
				$$->set_data_type("ERROR");
			}
			else if (is_zero($3->get_name())) {
				show_error(WARNING, MOD_BY_ZERO, "", errorout);
				$$->set_data_type("ERROR");
			}
			else {
				$$->set_data_type("INT");
			}
		}
		else if ($2->get_name() == "/") {
			if (is_zero($3->get_name())) {
				show_error(WARNING, DIV_BY_ZERO, "", errorout);
				$$->set_data_type("ERROR");
			}
			else {
				$$->set_data_type(type_cast($1->get_data_type(), $3->get_data_type()));
			}
		}
		else if ($2->get_name() == "*") {
			$$->set_data_type(type_cast($1->get_data_type(), $3->get_data_type()));
		}
		$$->set_rule("term : term MULOP unary_expression");
		$$->add_child($1); $$->add_child($2); $$->add_child($3);
	}
	;

unary_expression : ADDOP unary_expression {
		print_grammar_rule("unary_expression", "ADDOP unary_expression");
		$$ = new SymbolInfo("", "unary_expression");
		if ($2->get_data_type() == "VOID") {
			show_error(SEMANTIC, VOID_USAGE, "", errorout);
			$$->set_data_type("ERROR");
		}
		else $$->set_data_type($2->get_data_type());
		$$->set_rule("unary_expression : ADDOP unary_expression");
		$$->add_child($1); $$->add_child($2);
	}
	| NOT unary_expression {
		print_grammar_rule("unary_expression", "NOT unary_expression");
		$$ = new SymbolInfo("", "unary_expression");
		bool ok = true;
		if ($2->get_data_type() == "VOID") {
			show_error(SEMANTIC, VOID_USAGE, "", errorout);
			$$->set_data_type("ERROR");
			ok = false;
		}
		else if ($2->get_data_type() == "FLOAT") {
			show_error(WARNING, BITWISE_FLOAT, "", errorout);
		}
		if (ok) $$->set_data_type("INT");
		$$->set_rule("unary_expression : NOT unary_expression");
		$$->add_child($1); $$->add_child($2);
	}
	| factor {
		print_grammar_rule("unary_expression", "factor");
		$$ = new SymbolInfo($1->get_name(), "unary_expression", $1->get_data_type());
		$$->set_array($1->is_array());
		$$->set_rule("unary_expression : factor");
		$$->add_child($1);
	}
	;
	
factor : variable {
		print_grammar_rule("factor", "variable");
		$$ = new SymbolInfo($1->get_name(), "factor", $1->get_data_type());
		$$->set_array($1->is_array());
		$$->set_rule("factor : variable");
		$$->add_child($1);
	}
	| ID LPAREN argument_list RPAREN {
		print_grammar_rule("factor", "ID LPAREN argument_list RPAREN");
		$$ = new SymbolInfo("", "factor");
		SymbolInfo* res = sym->search($1->get_name(), 'A');
		if (res == nullptr) {
			show_error(SEMANTIC, UNDECLARED_FUNCTION, $1->get_name(), errorout);
		}
		else if (res->get_func_type() == NONE) {
			show_error(SEMANTIC, NOT_A_FUNCTION, $1->get_name(), errorout);
		}
		else if (res->get_func_type() == DECLARATION) {
			// show_error(SEMANTIC, UNDEFINED_FUNCTION, $1->get_name(), errorout);
			// gcc does not provide error in above scenario, runtime error happens
		}
		else if (res->get_param_list().size() < $3->get_param_list().size()) {
			show_error(SEMANTIC, TOO_MANY_ARGUMENTS, $1->get_name(), errorout);
		}
		else if (res->get_param_list().size() > $3->get_param_list().size()) {
			show_error(SEMANTIC, TOO_FEW_ARGUMENTS, $1->get_name(), errorout);
		}
		else {
			vector<Param> now = res->get_param_list();
			vector<Param> they = $3->get_param_list();
			for (int i = 0; i < now.size(); i++) {
				if ((now[i].data_type != they[i].data_type) || (now[i].is_array != they[i].is_array)) {
					// cerr << "Function: " << res->get_name() << endl;
					// cerr << "original: " << now[i].data_type << " given: " << they[i].data_type << " name: " << now[i].name << " line " << line_count << endl;
					string str = to_string(i + 1);
					str += " of \'" + $1->get_name() + "\'";
					show_error(SEMANTIC, ARG_TYPE_MISMATCH, str, errorout);
				}
			}
			$$->set_data_type(res->get_data_type());
		}
		$$->set_rule("factor : ID LPAREN argument_list RPAREN");
		$$->add_child($1); $$->add_child($2); $$->add_child($3); $$->add_child($4);
	}
	| LPAREN expression RPAREN {
		print_grammar_rule("factor", "LPAREN expression RPAREN");
		$$ = new SymbolInfo($2->get_name(), "factor", $2->get_data_type());
		$$->set_rule("factor : LPAREN expression RPAREN");
		$$->add_child($1); $$->add_child($2); $$->add_child($3);
	}
	| CONST_INT {
		print_grammar_rule("factor", "CONST_INT");
		$$ = new SymbolInfo($1->get_name(), "factor", "INT");
		$$->set_rule("factor : CONST_INT");
		$$->add_child($1);
	}
	| CONST_FLOAT {
		print_grammar_rule("factor", "CONST_FLOAT");
		$$ = new SymbolInfo($1->get_name(), "factor", "FLOAT");
		$$->set_rule("factor : CONST_FLOAT");
		$$->add_child($1);
	}
	| variable INCOP {
		print_grammar_rule("factor", "variable INCOP");
		$$ = new SymbolInfo("", "factor");
		if ($1->get_data_type() == "VOID") {
			show_error(SEMANTIC, VOID_USAGE, $1->get_name(), errorout);
			$$->set_data_type("ERROR");
		}
		else if ($1->get_data_type() == "ERROR") {
			// show_error(SEMANTIC, TYPE_ERROR, $1->get_name(), errorout);
			$$->set_data_type("ERROR");
		}
		else {
			$$->set_data_type($1->get_data_type());
		}
		$$->set_rule("factor : variable INCOP");
		$$->add_child($1); $$->add_child($2);
	}
	| variable DECOP {
		print_grammar_rule("factor", "variable DECOP");
		$$ = new SymbolInfo("", "factor");
		if ($1->get_data_type() == "VOID") {
			show_error(SEMANTIC, VOID_USAGE, "", errorout);
			$$->set_data_type("ERROR");
		}
		else if ($1->get_data_type() == "ERROR") {
			// show_error(SEMANTIC, TYPE_ERROR, "", errorout);
			$$->set_data_type("ERROR");
		}
		else {
			$$->set_data_type($1->get_data_type());
		}
		$$->set_rule("factor : variable DECOP");
		$$->add_child($1); $$->add_child($2);
	}
	;
	
argument_list : arguments {
		print_grammar_rule("argument_list", "arguments");
		$$ = new SymbolInfo("", "argument_list");
		$$->set_param_list($1->get_param_list());
		$$->set_rule("argument_list : arguments");
		$$->add_child($1);
	}
	| arguments error {
		print_grammar_rule("argument_list", "arguments");
		show_error(SYNTAX, S_ARG_LIST, "", errorout, syntax_error_line);
		$$ = new SymbolInfo("", "argument_list");
		$$->set_param_list($1->get_param_list());
		$$->set_rule("argument_list : arguments");
		$$->add_child($1);
	}
	| {
		// empty argument list, as one of the example of the sample suggests
		print_grammar_rule("argument_list", "");
		$$ = new SymbolInfo("", "argument_list");
	}
	;
	
arguments : arguments COMMA logic_expression {
		print_grammar_rule("arguments", "arguments COMMA logic_expression");
		$$ = new SymbolInfo("", "arguments");
		$$->set_param_list($1->get_param_list());
		$$->add_param($3->get_name(), $3->get_data_type(), $3->is_array());
		$$->set_rule("arguments : arguments COMMA logic_expression");
		$$->add_child($1); $$->add_child($2); $$->add_child($3);
	}
	| logic_expression {
		print_grammar_rule("arguments", "logic_expression");
		$$ = new SymbolInfo("", "arguments");
		$$->add_param($1->get_name(), $1->get_data_type(), $1->is_array());
		$$->set_rule("arguments : logic_expression");
		$$->add_child($1);
	}
	;

lcurls : LCURL {
		$$ = $1;
		sym->enter_scope();
		// why am I inserting symbols here? so that the parameters can be recognized in the newly created scope
		// but remember, in case of function prototypes, even though I am not inserting the symbols, I am still checking in 
		// insert_function() whether two non-empty names are same or not
		for (const Param& they : current_function_parameters) {
			if (they.name == "") {// nameless, no need to insert 
				// show_error(SYNTAX, S_PARAM_NAMELESS, "", errorout);
				errorout << "nameless parameter" << endl;
				continue;
			}
			SymbolInfo* another = new SymbolInfo(they.name, "ID", they.data_type);
			another->set_array(they.is_array);
			if (!sym->insert(another)) {
				// insertion failed
				show_error(SEMANTIC, PARAM_REDEFINITION, another->get_name(), errorout);
				// in sample output, after any failure, the next arguments are not inserted to the symbol table
				// so we will break the loop
				free_s(another);
				break;
			}
		}
		current_function_parameters.clear();
	}
	;
 
%%

int main(int argc,char *argv[]) {	
	if (argc < 2) {
		cout << "Please Provide Input File\n";
		exit(1);
	}
	FILE *fp;
	if((fp = fopen(argv[1], "r")) == NULL) {
		cout << "Cannot Open Input File\n";
		exit(1);
	}

	treeout.open("parsetree.txt");
	errorout.open("error.txt");
	logout.open("log.txt");

	sym = new SymbolTable(BUCKET_SIZE);

	yyin = fp;
	yyparse();

	fclose(yyin);
	delete sym;
	current_function_parameters.clear();

	logout << "Total Lines: " << line_count << endl;
	logout << "Total Errors: " << error_count << endl;
	treeout.close();
	errorout.close();
	logout.close();
	return 0;
}

