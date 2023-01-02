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

int line_count = 1;
int error_count = 0;
SymbolTable *sym;
extern FILE* yyin;
vector<SymbolInfo*> current_function_parameters;

ofstream treeout, errorout, logout;

void yyerror(const string& s) {}
int yyparse(void);
int yylex(void);

void print_grammar_rule(const string& parent, const string& children) {
	logout << parent << " : " << children << endl;
}

void insert_function(SymbolInfo* function, const string& type_specifier, const vector<SymbolInfo*> param_list) {
	// took the symbol info class, not string for function name
	// so that it can be used for inserting to symbol table as well
	function->set_type("FUNCTION");
	function->set_data_type(type_specifier);
	function->set_func_definition(true);
	function->set_param_list(param_list);

	if (function->is_func_definition()) {
		// no parameter can be nameless in a function definition
		for (int i = 0; i < param_list.size(); i++) {
			if (param_list[i]->get_name() == "") {
				show_error(SEMANTIC, PARAM_NAMELESS, function->get_name(), errorout);
			}
		}
	}

	// if it is a function definition, the check is done in lcurls -> LCURL, check there
	// but if prototype, check not done there
	if (function->is_func_declaration()) {
		for (int i = 0; i < param_list.size(); i++) {
			for (int j = i + 1; j < param_list.size(); j++) {
				// checking if any two parameters have same name except both being ""
				if (param_list[i]->get_name() == "") continue;
				if (param_list[i]->get_name() == param_list[j]->get_name()) {
					show_error(SEMANTIC, PARAM_REDEFINITION, function->get_name(), errorout);
				}
			}
		}
	}

	bool success = sym->insert(function);
	if (success) return; // no function definition available, so insert it as it is

	SymbolInfo* prev_func = sym->search(function->get_name());
	assert(prev_func != nullptr); // some prev instance must be there, otherwise success would be true

	if (!prev_func->is_func_declaration()) {
		// so it has been already defined either as a function or as an identifier
		if (prev_func->is_func_definition()) {
			// redefining this function, an error
			show_error(SEMANTIC, FUNC_REDEFINITION, function->get_name(), errorout);
		}
		else {
			// previously not a function, now as a function
			show_error(SEMANTIC, DIFFERENT_REDECLARATION, function->get_name(), errorout);
		}
	}
	else {
		// previous one was a prototype
		if (prev_func->get_data_type() != type_specifier) {
			show_error(SEMANTIC, CONFLICTING_TYPE, function->get_name(), errorout);
		}
		else if (prev_func->get_param_list().size() != param_list.size()) {
			// both same error as specification
			show_error(SEMANTIC, CONFLICTING_TYPE, function->get_name(), errorout);
		}
		else {
			vector<SymbolInfo*> prev_list = prev_func->get_param_list();
			vector<SymbolInfo*> now_list = function->get_param_list();
			for (int i = 0; i < prev_list.size(); i++) {
				if (prev_list[i]->get_data_type() != now_list[i]->get_data_type()) {
					show_error(SEMANTIC, CONFLICTING_TYPE, function->get_name(), errorout);
				}
			}
		}
	}
}

inline bool check_type_specifier(SymbolInfo* symbol) {
	if (symbol->get_data_type() == "VOID") {
		show_error(SEMANTIC, VOID_TYPE, symbol->get_name(), errorout);
		return false;
	}
	return true;
}

inline int is_number(const string& number) {
	// first check if float
	cerr << "number: " << number << endl;
	cerr << "line: " << line_count << endl;
	if (number == "") return -1;
	for (int i = 0; i < number.size(); i++) {
		if ((number[i] < '0' || number[i] > '9') && number[i] != '.') return -1;
	}
	int dot_count = 0;
	for (int i = 0; i < number.size(); i++) {
		if (number[i] == '.') {
			dot_count++;
			if (dot_count > 1) return -1;
		}
	}
	return (dot_count == 0) ? 0 : 1; // 0 means int, 1 means float
}
%}

%union {
	SymbolInfo* symbol_info;
}

%token <symbol_info> IF ELSE FOR WHILE DO BREAK INT CHAR FLOAT DOUBLE VOID RETURN SWITCH CASE DEFAULT CONTINUE PRINTLN CONST_INT CONST_FLOAT ID ADDOP MULOP INCOP DECOP RELOP ASSIGNOP LOGICOP BITOP NOT LPAREN RPAREN LCURL RCURL LTHIRD RTHIRD COMMA SEMICOLON
%type <symbol_info> start program unit var_declaration func_declaration func_definition type_specifier parameter_list compound_statement statements declaration_list statement expression expression_statement logic_expression rel_expression simple_expression term unary_expression factor variable argument_list arguments lcurls

%%

start : program {
		print_grammar_rule("start", "program");
		$$ = new SymbolInfo("", "start");
	}
	;

program : program unit {
		print_grammar_rule("program", "program unit");
		$$ = new SymbolInfo("", "program");	
	}
	| unit {
		print_grammar_rule("program", "unit");
		$$ = new SymbolInfo("", "program");
	}
	;
	
unit : var_declaration {
		print_grammar_rule("unit", "var_declaration");
		$$ = new SymbolInfo("", "unit");
	}
    | func_declaration {
		print_grammar_rule("unit", "func_declaration");
		$$ = new SymbolInfo("", "unit");
	}
    | func_definition {
		print_grammar_rule("unit", "func_definition");
		$$ = new SymbolInfo("", "unit");
	}
	| error {
		yyclearin; // clears the lookahead
		yyerrok; // now you can start normal parsing
		show_error(SYNTAX, S_UNIT, "", errorout);
		$$ = new SymbolInfo("", "unit");
	}
    ;
     
func_declaration : type_specifier ID LPAREN parameter_list RPAREN SEMICOLON {
		print_grammar_rule("func_declaration", "type_specifier ID LPAREN parameter_list RPAREN SEMICOLON");
		current_function_parameters.clear(); // resetting for this function
		$$ = new SymbolInfo("", "func_declaration");
		$2->set_func_declaration(true);
		$2->set_param_list($4->get_param_list());
		$2->set_type("FUNCTION");
		$2->set_data_type($1->get_data_type());

		bool success = sym->insert($2);
		if (!success) {
			SymbolInfo* prev_func = sym->search($2->get_name());
			assert(prev_func != nullptr); // some prev instance must be there, otherwise success would be true
			if (prev_func->is_func_declaration()) {
				// so it was a function
				show_error(SEMANTIC, FUNC_REDEFINITION, $2->get_name(), errorout);
			}
			else {
				// previously not a function, now as a function
				show_error(SEMANTIC, DIFFERENT_REDECLARATION, $2->get_name(), errorout);
			}
		}
	}
	| type_specifier ID LPAREN error RPAREN SEMICOLON {
		print_grammar_rule("func_declaration", "type_specifier ID LPAREN parameter_list RPAREN SEMICOLON");
		current_function_parameters.clear();
		$$ = new SymbolInfo("", "func_declaration");
		$2->set_func_declaration(true);
		$2->set_type("FUNCTION");
		$2->set_data_type($1->get_data_type());

		bool success = sym->insert($2);
		if (!success) {
			SymbolInfo* prev_func = sym->search($2->get_name());
			assert(prev_func != nullptr); // some prev instance must be there, otherwise success would be true
			if (prev_func->is_func_declaration()) {
				// so it was a function
				show_error(SEMANTIC, FUNC_REDEFINITION, $2->get_name(), errorout);
			}
			else {
				// previously not a function, now as a function
				show_error(SEMANTIC, DIFFERENT_REDECLARATION, $2->get_name(), errorout);
			}
		}
	}
	| type_specifier ID LPAREN RPAREN SEMICOLON {
		print_grammar_rule("func_declaration", "type_specifier ID LPAREN parameter_list RPAREN SEMICOLON");
		current_function_parameters.clear();
		$$ = new SymbolInfo("", "func_declaration");
		$2->set_func_declaration(true);
		$2->set_type("FUNCTION");
		$2->set_data_type($1->get_data_type());

		bool success = sym->insert($2);
		if (!success) {
			SymbolInfo* prev_func = sym->search($2->get_name());
			assert(prev_func != nullptr); // some prev instance must be there, otherwise success would be true
			if (prev_func->is_func_declaration()) {
				// so it was a function
				show_error(SEMANTIC, FUNC_REDEFINITION, $2->get_name(), errorout);
			}
			else {
				// previously not a function, now as a function
				show_error(SEMANTIC, DIFFERENT_REDECLARATION, $2->get_name(), errorout);
			}
		}
	}
	;
	 
func_definition : type_specifier ID LPAREN parameter_list RPAREN { insert_function($2, $1->get_data_type(), $4->get_param_list()); } compound_statement {
		print_grammar_rule("func_definition", "type_specifier ID LPAREN parameter_list RPAREN compound_statement");
		$$ = new SymbolInfo("", "func_definition");
	}
	| type_specifier ID LPAREN error RPAREN { insert_function($2, $1->get_data_type(), {}); } compound_statement {
		print_grammar_rule("func_definition", "type_specifier ID LPAREN parameter_list RPAREN compound_statement");
		$$ = new SymbolInfo("", "func_definition");
		show_error(SYNTAX, S_PARAM_FUNC_DEFINITION, "", errorout);
	}
	| type_specifier ID LPAREN RPAREN { insert_function($2, $1->get_data_type(), $4->get_param_list()); } compound_statement {
		print_grammar_rule("func_definition", "type_specifier ID LPAREN RPAREN compound_statement");
		$$ = new SymbolInfo("", "func_definition");
	}
	;				

parameter_list : parameter_list COMMA type_specifier ID {
		print_grammar_rule("parameter_list", "parameter_list COMMA type_specifier ID");
		$$ = new SymbolInfo("", "parameter_list");
		SymbolInfo* new_param = new SymbolInfo($4->get_name(), "ID", $3->get_data_type());
		$$->set_param_list($1->get_param_list());
		$$->add_param(new_param);
		check_type_specifier($3);
		current_function_parameters = $$->get_param_list();
	}
	| parameter_list COMMA type_specifier {
		print_grammar_rule("parameter_list", "parameter_list COMMA type_specifier");
		$$ = new SymbolInfo("", "parameter_list");
		SymbolInfo* new_param = new SymbolInfo("", "ID", $3->get_data_type()); // later check if this nameless parameter is used in function definition. if yes, then show error
		$$->set_param_list($1->get_param_list());
		$$->add_param(new_param);
		check_type_specifier($3);
		current_function_parameters = $$->get_param_list();
	}
	| type_specifier ID {
		print_grammar_rule("parameter_list", "type_specifier ID");
		$$ = new SymbolInfo("", "parameter_list");
		SymbolInfo* new_param = new SymbolInfo($2->get_name(), "ID", $1->get_data_type());
		$$->add_param(new_param);
		check_type_specifier($1);
		current_function_parameters = $$->get_param_list();
	}
	| type_specifier {
		print_grammar_rule("parameter_list", "type_specifier");
		$$ = new SymbolInfo("", "parameter_list");
		SymbolInfo* new_param = new SymbolInfo("", "ID", $1->get_data_type()); // later check if this nameless parameter is used in function definition. if yes, then show error
		$$->add_param(new_param);
		check_type_specifier($1);
		current_function_parameters = $$->get_param_list();
	}
	;
	
compound_statement : lcurls statements RCURL {
		print_grammar_rule("compound_statement", "LCURL statements RCURL");
		$$ = new SymbolInfo("", "compound_statement");
		sym->print('A', logout);
		sym->exit_scope();
	}
	| lcurls error RCURL {
		print_grammar_rule("compound_statement", "LCURL RCURL");
		$$ = new SymbolInfo("", "compound_statement");
		sym->print('A', logout);
		sym->exit_scope();
	}
	| lcurls RCURL {
		print_grammar_rule("compound_statement", "LCURL RCURL");
		$$ = new SymbolInfo("", "compound_statement");
		sym->print('A', logout);
		sym->exit_scope();
	}
	;
 		    
var_declaration : type_specifier declaration_list SEMICOLON {
		print_grammar_rule("var_declaration", "type_specifier declaration_list SEMICOLON");
		$$ = new SymbolInfo("", "var_declaration");
		bool ok = check_type_specifier($1);
		if (ok) {
			auto cur_list = $2->get_declaration_list();
			for (int i = 0; i < cur_list.size(); i++) {
				// now we will set the data_type of all these symbols to $1
				cur_list[i]->set_data_type($1->get_data_type());
				if (!sym->insert(cur_list[i])) {
					// insertion failed
					show_error(SEMANTIC, VARIABLE_REDEFINITION, cur_list[i]->get_name(), errorout);
				}
			}
		}
	}
	| type_specifier error SEMICOLON {
		print_grammar_rule("var_declaration", "type_specifier declaration_list SEMICOLON");
		$$ = new SymbolInfo("", "var_declaration");
		show_error(SYNTAX, S_DECL_VAR_DECLARATION, "", errorout);
	}
	;
 		 
type_specifier	: INT {
		print_grammar_rule("type_specifier", "INT");
		$$ = new SymbolInfo("", "type_specifier", "int");
	}
	| FLOAT {
		print_grammar_rule("type_specifier", "FLOAT");
		$$ = new SymbolInfo("", "type_specifier", "float");
	}
	| VOID {
		print_grammar_rule("type_specifier", "VOID");
		$$ = new SymbolInfo("", "type_specifier", "void");
	}
	;
 		
declaration_list : declaration_list COMMA ID {
		print_grammar_rule("declaration_list", "declaration_list COMMA ID");
		$$ = new SymbolInfo("", "declaration_list");
		SymbolInfo* new_symbol = new SymbolInfo($3->get_name(), "ID");
		$$->set_declaration_list($1->get_declaration_list());
		$$->add_declaration(new_symbol);
	}
	| declaration_list COMMA ID LTHIRD CONST_INT RTHIRD {
		print_grammar_rule("declaration_list", "declaration_list COMMA ID LTHIRD CONST_INT RTHIRD");
		$$ = new SymbolInfo("", "declaration_list");
		$$->set_declaration_list($1->get_declaration_list());
		$3->set_array(true);
		$3->set_array_size(stoi($5->get_name()));
		$$->add_declaration($3);
	}
	| ID {
		print_grammar_rule("declaration_list", "ID");
		$$ = new SymbolInfo("", "declaration_list");
		SymbolInfo* new_symbol = new SymbolInfo($1->get_name(), "ID");
		$$->add_declaration(new_symbol);
	}
	| ID LTHIRD CONST_INT RTHIRD {
		print_grammar_rule("declaration_list", "ID LTHIRD CONST_INT RTHIRD");
		$$ = new SymbolInfo("", "declaration_list");
		$1->set_array(true);
		$1->set_array_size(stoi($3->get_name()));
		$$->add_declaration($1);
	}
	;
 		  
statements : statement {
		print_grammar_rule("statements", "statement");
		$$ = new SymbolInfo("", "statements");
	}
	| statements statement {
		print_grammar_rule("statements", "statements statement");
		$$ = new SymbolInfo("", "statements");
	}
	;
	   
statement : var_declaration {
		print_grammar_rule("statement", "var_declaration");
		$$ = new SymbolInfo("", "statement");
	}
	| expression_statement {
		print_grammar_rule("statement", "expression_statement");
		$$ = new SymbolInfo("", "statement");
		$$->set_name($1->get_name());
	}
	| compound_statement {
		print_grammar_rule("statement", "compound_statement");
		$$ = new SymbolInfo("", "statement");
	}
	| FOR LPAREN expression_statement expression_statement expression RPAREN statement {
		print_grammar_rule("statement", "FOR LPAREN expression_statement expression_statement expression RPAREN statement");
		$$ = new SymbolInfo("", "statement");
	}
	| IF LPAREN expression RPAREN statement {
		print_grammar_rule("statement", "IF LPAREN expression RPAREN statement");
		$$ = new SymbolInfo("", "statement");
	}
	| IF LPAREN expression RPAREN statement ELSE statement {
		print_grammar_rule("statement", "IF LPAREN expression RPAREN statement ELSE statement");
		$$ = new SymbolInfo("", "statement");
	}
	| WHILE LPAREN expression RPAREN statement {
		print_grammar_rule("statement", "WHILE LPAREN expression RPAREN statement");
		$$ = new SymbolInfo("", "statement");
	}
	| PRINTLN LPAREN ID RPAREN SEMICOLON {
		print_grammar_rule("statement", "PRINTLN LPAREN ID RPAREN SEMICOLON");
		$$ = new SymbolInfo("", "statement");
		if (sym->search($3->get_name()) == nullptr) {
			show_error(SEMANTIC, UNDECLARED_VARIABLE, $3->get_name(), errorout);
		}
	}
	| RETURN expression SEMICOLON {
		print_grammar_rule("statement", "RETURN expression SEMICOLON");
		$$ = new SymbolInfo("", "statement");
	}
	;
	  
expression_statement : SEMICOLON {
		print_grammar_rule("expression_statement", "SEMICOLON");
		$$ = new SymbolInfo("", "expression_statement");
	}
	| expression SEMICOLON {
		print_grammar_rule("expression_statement", "expression SEMICOLON");
		$$ = new SymbolInfo("", "expression_statement");
		$$->set_name($1->get_name());
		$$->set_data_type($1->get_data_type()); // result of an expression will have a certain data type, won't it?
	}
	| error SEMICOLON {
		yyclearin; // clear the lookahead token
		yyerrok; // clear the error stack
		show_error(SYNTAX, S_EXP_STATEMENT, "", errorout);
		$$ = new SymbolInfo("", "expression_statement");
	}
	;
	  
variable : ID {
		print_grammar_rule("variable", "ID");
		$$ = new SymbolInfo($1->get_name(), "VARIABLE", $1->get_data_type());
		
		SymbolInfo* res = sym->search($1->get_name());
		if (res == nullptr) {
			show_error(SEMANTIC, UNDECLARED_VARIABLE, $1->get_name(), errorout);
		}
		else if (res->is_array()) {
			// declared as an array, but used like normal variable, so error
			show_error(SEMANTIC, ARRAY_AS_VAR, $1->get_name(), errorout);
		}
		else if (res->is_func_definition() || res->is_func_declaration()) {
			// declared as a function, but used like normal variable, so error
			show_error(SEMANTIC, FUNC_AS_VAR, $1->get_name(), errorout);
		}
		else {
			$$->set_data_type(res->get_data_type());
			$$->set_array(false);
		}
	}	
	| ID LTHIRD expression RTHIRD {
		// it has to be an array now
		print_grammar_rule("variable", "ID LTHIRD expression RTHIRD");
		$$ = new SymbolInfo($1->get_name(), "VARIABLE", $1->get_data_type());
		
		SymbolInfo* res = sym->search($1->get_name());
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
		else if (is_number($3->get_name()) == 0 && stoi($3->get_name()) >= res->get_array_size()) {
			// array index is out of bounds, so error
			show_error(SEMANTIC, INDEX_OUT_OF_BOUNDS, $1->get_name(), errorout);
		}
		else {
			$$->set_data_type(res->get_data_type());
			$$->set_array(true);
		}
	}
	;
	 
expression : logic_expression {
		print_grammar_rule("expression", "logic_expression");
		$$ = new SymbolInfo("", "expression");
		$$->set_data_type($1->get_data_type());
	}	
	| variable ASSIGNOP logic_expression {
		print_grammar_rule("expression", "variable ASSIGNOP logic_expression");
		$$ = new SymbolInfo("", "expression");

		if ($1->get_data_type() == "VOID" || $3->get_data_type() == "VOID") {
			show_error(SEMANTIC, VOID_USAGE, "", errorout);
		}
		else if ($1->get_data_type() == "ERROR" || $3->get_data_type() == "ERROR") {
			show_error(SEMANTIC, TYPE_ERROR, "", errorout);
		}
		else if ($1->get_data_type() == "INT") {
			if ($3->get_data_type() == "FLOAT") {
				show_error(WARNING, FLOAT_TO_INT, "", errorout);
			}
		}
		$$->set_data_type($1->get_data_type());
		// $1 should not be void by any means, but still
	}	
	;
			
logic_expression : rel_expression {
		print_grammar_rule("logic_expression", "rel_expression");
		$$ = new SymbolInfo("", "logic_expression");
		$$->set_data_type($1->get_data_type());
		$$->set_array($1->is_array());
	}
	| rel_expression LOGICOP rel_expression {
		print_grammar_rule("logic_expression", "rel_expression LOGICOP rel_expression");
		$$ = new SymbolInfo("", "logic_expression");
		$$->set_data_type("INT"); // result of any logical operation should be boolean in fact
		// I have never assigned void type to any rel_expression at any point, so no need to check that either
	}
	;
			
rel_expression : simple_expression {
		print_grammar_rule("rel_expression", "simple_expression");
		$$ = new SymbolInfo("", "rel_expression");
		$$->set_data_type($1->get_data_type());
		$$->set_array($1->is_array());
	}
	| simple_expression RELOP simple_expression {
		print_grammar_rule("rel_expression", "simple_expression RELOP simple_expression");
		$$ = new SymbolInfo("", "rel_expression");
		if ($1->get_data_type() == "VOID" || $3->get_data_type() == "VOID") {
			show_error(SEMANTIC, VOID_USAGE, "", errorout);
		}
		else {
			$$->set_data_type("INT"); // result of any comparison should be boolean in fact
		}
	}	
	;
				
simple_expression : term {
		print_grammar_rule("simple_expression", "term");
		$$ = new SymbolInfo("", "simple_expression");
		$$->set_data_type($1->get_data_type());
		$$->set_array($1->is_array());
	}
	| simple_expression ADDOP term {
		print_grammar_rule("simple_expression", "simple_expression ADDOP term");
		$$ = new SymbolInfo("", "simple_expression");
		if ($1->get_data_type() == "VOID" || $3->get_data_type() == "VOID") {
			show_error(SEMANTIC, VOID_USAGE, "", errorout);
		}
		else if ($1->get_data_type() == "FLOAT" || $3->get_data_type() == "FLOAT") {
			$$->set_data_type("FLOAT");
		}
		else {
			$$->set_data_type("INT");
		}
	}
	;
					
term : unary_expression {
		print_grammar_rule("term", "unary_expression");
		$$ = new SymbolInfo("", "term");
		$$->set_data_type($1->get_data_type());
		$$->set_array($1->is_array());
	}
	| term MULOP unary_expression {
		print_grammar_rule("term", "term MULOP unary_expression");
		$$ = new SymbolInfo("", "term");
		if ($1->get_data_type() == "VOID" || $3->get_data_type() == "VOID") {
			show_error(SEMANTIC, VOID_USAGE, "", errorout);
		}
		else if ($1->get_data_type() == "ERROR" || $3->get_data_type() == "ERROR") {
			show_error(SEMANTIC, TYPE_ERROR, "", errorout);
		}
		else if ($2->get_name() == "%") {
			if ($1->get_data_type() == "FLOAT" || $3->get_data_type() == "FLOAT") {
				show_error(SEMANTIC, MOD_OPERAND, "", errorout);
			}
			else if (is_number($3->get_name()) == 0 && stoi($3->get_name()) == 0) {
				show_error(WARNING, MOD_BY_ZERO, "", errorout);
			}
			else {
				$$->set_data_type("INT");
			}
		}
		else if ($2->get_name() == "/") {
			if (is_number($2->get_name()) != -1) {
				string num = $3->get_name();
				bool is_zero = false;
				if ($3->get_data_type() == "INT" && stoi(num) == 0) {
					is_zero = true;
				}
				else if ($3->get_data_type() == "FLOAT") {
					float numf = stof(num);
					if (fabs(numf) < 1e-9) is_zero = true;
				}
				if (is_zero) {
					show_error(WARNING, DIV_BY_ZERO, "", errorout);
				}
			}
			if ($1->get_data_type() == "FLOAT" || $3->get_data_type() == "FLOAT") {
				$$->set_data_type("FLOAT");
			}
			else {
				$$->set_data_type("INT");
			}
		}
	}
	;

unary_expression : ADDOP unary_expression {
		print_grammar_rule("unary_expression", "ADDOP unary_expression");
		$$ = new SymbolInfo("", "unary_expression");
		$$->set_name($2->get_name());
		if ($2->get_data_type() == "VOID") {
			show_error(SEMANTIC, VOID_USAGE, "", errorout);
			$$->set_data_type("ERROR");
		}
		else $$->set_data_type($2->get_data_type());
	}
	| NOT unary_expression {
		print_grammar_rule("unary_expression", "ADDOP unary_expression");
		$$ = new SymbolInfo("", "unary_expression");
		$$->set_name($2->get_name());
		if ($2->get_data_type() == "VOID") {
			show_error(SEMANTIC, VOID_USAGE, "", errorout);
			$$->set_data_type("ERROR");
		}
		else $$->set_data_type($2->get_data_type());
	}
	| factor {
		print_grammar_rule("unary_expression", "factor");
		$$ = new SymbolInfo($1->get_name(), "unary_expression");
		$$->set_name($1->get_name());
		$$->set_data_type($1->get_data_type());
		$$->set_array($1->is_array());
	}
	;
	
factor : variable {
		print_grammar_rule("factor", "variable");
		$$ = new SymbolInfo("", "factor");
		$$->set_data_type($1->get_data_type());
		$$->set_array($1->is_array());
	}
	| ID LPAREN argument_list RPAREN {
		print_grammar_rule("factor", "ID LPAREN argument_list RPAREN");
		$$ = new SymbolInfo("", "factor");
		SymbolInfo* res = sym->search($1->get_name());
		if (res == nullptr) {
			show_error(SEMANTIC, UNDECLARED_FUNCTION, $1->get_name(), errorout);
		}
		else if (!res->is_func_declaration() && !res->is_func_definition()) {
			show_error(SEMANTIC, NOT_A_FUNCTION, $1->get_name(), errorout);
		}
		else if (res->is_func_declaration() && !res->is_func_definition()) {
			show_error(SEMANTIC, UNDEFINED_FUNCTION, $1->get_name(), errorout);
		}
		else if (res->get_param_list().size() < $3->get_param_list().size()) {
			show_error(SEMANTIC, TOO_MANY_ARGUMENTS, $1->get_name(), errorout);
		}
		else if (res->get_param_list().size() > $3->get_param_list().size()) {
			show_error(SEMANTIC, TOO_FEW_ARGUMENTS, $1->get_name(), errorout);
		}
	}
	| LPAREN expression RPAREN {
		print_grammar_rule("factor", "LPAREN expression RPAREN");
		$$ = new SymbolInfo("", "factor");
		$$->set_data_type($2->get_data_type());
	}
	| CONST_INT {
		print_grammar_rule("factor", "CONST_INT");
		$$ = new SymbolInfo($1->get_name(), "factor", "INT");
	}
	| CONST_FLOAT {
		print_grammar_rule("factor", "CONST_INT");
		$$ = new SymbolInfo($1->get_name(), "factor", "INT");
	}
	| variable INCOP {
		print_grammar_rule("factor", "variable INCOP");
		$$ = new SymbolInfo("", "factor");
		$$->set_name($1->get_name());
		if ($1->get_data_type() == "VOID") {
			show_error(SEMANTIC, VOID_USAGE, "", errorout);
		}
		else {
			$$->set_data_type($1->get_data_type());
		}
	}
	| variable DECOP {
		print_grammar_rule("factor", "variable DECOP");
		$$ = new SymbolInfo("", "factor");
		$$->set_name($1->get_name());
		if ($1->get_data_type() == "VOID") {
			show_error(SEMANTIC, VOID_USAGE, "", errorout);
		}
		else {
			$$->set_data_type($1->get_data_type());
		}
	}
	;
	
argument_list : arguments
			  |
			  ;
	
arguments : arguments COMMA logic_expression
	      | logic_expression
	      ;

lcurls : LCURL {
		$$ = $1;
		sym->enter_scope();
		for (SymbolInfo* they : current_function_parameters) {
			if (they->get_name() == "") // nameless, no need to insert
				continue;
			if (!sym->insert(they)) {
				// insertion failed
				show_error(SEMANTIC, PARAM_REDEFINITION, they->get_name(), errorout);
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
	treeout.close();
	errorout.close();
	logout.close();
	
	return 0;
}

