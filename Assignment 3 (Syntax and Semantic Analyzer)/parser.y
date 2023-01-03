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
SymbolTable *sym;
extern FILE* yyin;
vector<SymbolInfo*> current_function_parameters;

ofstream treeout, errorout, logout;

void yyerror(const string& s) {}
int yyparse(void);
int yylex(void);

inline void print_grammar_rule(const string& parent, const string& children) {
	logout << parent << " : " << children << " " << endl;
}

inline void show_syntax_error() {
	logout << "Error at line no " << line_count << " : syntax error" << endl;
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
				return; // returning as any such function is not acceptable
			}
		}
	}

	// if it is a function definition, the check is done in lcurls -> LCURL, check there
	// but if prototype, check not done there
	if (function->is_func_declaration() && !function->is_func_definition()) {
		for (int i = 0; i < param_list.size(); i++) {
			for (int j = i + 1; j < param_list.size(); j++) {
				// checking if any two parameters have same name except both being ""
				if (param_list[i]->get_name() == "") continue;
				if (param_list[i]->get_name() == param_list[j]->get_name()) {
					show_error(SEMANTIC, PARAM_REDEFINITION, param_list[i]->get_name(), errorout);
					return; // returning as any such function is not acceptable
				}
			}
		}
	}

	// cerr << "Function " << function->get_name() << endl;
	// for (auto they : param_list) {
	// 	cerr << they->get_name() << " " << they->get_data_type() << endl;
	// }
	bool success = sym->insert(function);
	if (success) return; // no function definition available, so insert it as it is

	SymbolInfo* prev_func = sym->search(function->get_name(), 'A');
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

inline bool check_type_specifier(SymbolInfo* ty, const string& name) {
	if (ty->get_data_type() == "VOID") {
		show_error(SEMANTIC, VOID_TYPE, name, errorout);
		return false;
	}
	return true;
}

inline int is_number(const string& number) {
	// first check if float
	// cerr << "number: " << number << endl;
	// cerr << "line: " << line_count << endl;
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

inline bool is_zero(const string& str) {
	// already guaranteed to be a valid number from lexer, so no need to check that again
	for (char c : str) {
		if (c != '0' && c != 'e' && c != 'E') return false;
	}
	return true;
}

%}

%nonassoc LOWER_THAN_ELSE
%nonassoc ELSE

%error-verbose

%union {
	SymbolInfo* symbol_info;
}

%token <symbol_info> IF ELSE FOR WHILE DO BREAK INT CHAR FLOAT DOUBLE VOID RETURN SWITCH CASE DEFAULT CONTINUE PRINTLN CONST_INT CONST_FLOAT ID ADDOP MULOP INCOP DECOP RELOP ASSIGNOP LOGICOP BITOP NOT LPAREN RPAREN LCURL RCURL LSQUARE RSQUARE COMMA SEMICOLON
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
		show_syntax_error();
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
			SymbolInfo* prev_func = sym->search($2->get_name(), 'A');
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
		print_grammar_rule("func_declaration", "type_specifier ID LPAREN RPAREN SEMICOLON");
		current_function_parameters.clear();
		$$ = new SymbolInfo("", "func_declaration");
		$2->set_func_declaration(true);
		$2->set_type("FUNCTION");
		$2->set_data_type($1->get_data_type());

		bool success = sym->insert($2);
		if (!success) {
			SymbolInfo* prev_func = sym->search($2->get_name(), 'A');
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
		print_grammar_rule("func_declaration", "type_specifier ID LPAREN RPAREN SEMICOLON");
		current_function_parameters.clear();
		$$ = new SymbolInfo("", "func_declaration");
		$2->set_func_declaration(true);
		$2->set_type("FUNCTION");
		$2->set_data_type($1->get_data_type());

		bool success = sym->insert($2);
		if (!success) {
			SymbolInfo* prev_func = sym->search($2->get_name(), 'A');
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
		show_syntax_error();
	}
	| type_specifier ID LPAREN RPAREN { insert_function($2, $1->get_data_type(), {}); } compound_statement {
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
		check_type_specifier($3, $4->get_name());
		current_function_parameters = $$->get_param_list();
	}
	| parameter_list COMMA type_specifier {
		print_grammar_rule("parameter_list", "parameter_list COMMA type_specifier");
		$$ = new SymbolInfo("", "parameter_list");
		SymbolInfo* new_param = new SymbolInfo("", "ID", $3->get_data_type()); // later check if this nameless parameter is used in function definition. if yes, then show error
		$$->set_param_list($1->get_param_list());
		$$->add_param(new_param);
		check_type_specifier($3, "");
		current_function_parameters = $$->get_param_list();
	}
	| type_specifier ID {
		print_grammar_rule("parameter_list", "type_specifier ID");
		$$ = new SymbolInfo("", "parameter_list");
		SymbolInfo* new_param = new SymbolInfo($2->get_name(), "ID", $1->get_data_type());
		$$->add_param(new_param);
		check_type_specifier($1, $2->get_name());
		current_function_parameters = $$->get_param_list();
	}
	| type_specifier {
		print_grammar_rule("parameter_list", "type_specifier");
		$$ = new SymbolInfo("", "parameter_list");
		SymbolInfo* new_param = new SymbolInfo("", "ID", $1->get_data_type()); // later check if this nameless parameter is used in function definition. if yes, then show error
		$$->add_param(new_param);
		check_type_specifier($1, "");
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
		string str = "";
		auto cur_list = $2->get_declaration_list();
		for (int i = 0; i < cur_list.size(); i++) {
			str += cur_list[i]->get_name();
			if (i != cur_list.size() - 1) str += ", ";
		}
		bool ok = check_type_specifier($1, str);
		if (ok) {
			for (int i = 0; i < cur_list.size(); i++) {
				// now we will set the data_type of all these symbols to $1
				cur_list[i]->set_data_type($1->get_data_type());
				// cerr << cur_list[i]->get_data_type() << " " << cur_list[i]->get_name() << endl;
				SymbolInfo* res = sym->search(cur_list[i]->get_name(), 'C');
				if (res == nullptr) {
					sym->insert(cur_list[i]);
				}
				else if (res->get_data_type() != cur_list[i]->get_data_type()) {
					// cerr << "Previous: " << res->get_data_type() << " current: " << cur_list[i]->get_data_type() << " " << cur_list[i]->get_name() << " line: " << line_count << endl; 
					show_error(SEMANTIC, CONFLICTING_TYPE, cur_list[i]->get_name(), errorout);
				}
				else {
					show_error(SEMANTIC, VARIABLE_REDEFINITION, cur_list[i]->get_name(), errorout);
				}
			}
		}
	}
	| type_specifier error SEMICOLON {
		print_grammar_rule("var_declaration", "type_specifier declaration_list SEMICOLON");
		$$ = new SymbolInfo("", "var_declaration");
		show_error(SYNTAX, S_DECL_VAR_DECLARATION, "", errorout);
		show_syntax_error();
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
	| declaration_list COMMA ID LSQUARE CONST_INT RSQUARE {
		print_grammar_rule("declaration_list", "declaration_list COMMA ID LSQUARE CONST_INT RSQUARE");
		$$ = new SymbolInfo("", "declaration_list");
		SymbolInfo* new_symbol = new SymbolInfo($3->get_name(), "ID");
		new_symbol->set_array(true);
		$$->set_declaration_list($1->get_declaration_list());
		$$->add_declaration(new_symbol);
	}
	| ID {
		print_grammar_rule("declaration_list", "ID");
		$$ = new SymbolInfo("", "declaration_list");
		SymbolInfo* new_symbol = new SymbolInfo($1->get_name(), "ID");
		$$->add_declaration(new_symbol);
	}
	| ID LSQUARE CONST_INT RSQUARE {
		print_grammar_rule("declaration_list", "ID LSQUARE CONST_INT RSQUARE");
		$$ = new SymbolInfo("", "declaration_list");
		SymbolInfo* new_symbol = new SymbolInfo($1->get_name(), "ID");
		new_symbol->set_array(true);
		$$->add_declaration(new_symbol);
	}
	;
 		  
statements : statement {
		print_grammar_rule("statements", "statement");
		$$ = new SymbolInfo($1->get_name(), "statements");
	}
	| statements statement {
		print_grammar_rule("statements", "statements statement");
		$$ = new SymbolInfo($1->get_name(), "statements");
	}
	;
	   
statement : var_declaration {
		print_grammar_rule("statement", "var_declaration");
		$$ = new SymbolInfo($1->get_name(), "statement");
	}
	| expression_statement {
		print_grammar_rule("statement", "expression_statement");
		$$ = new SymbolInfo($1->get_name(), "statement");
	}
	| compound_statement {
		print_grammar_rule("statement", "compound_statement");
		$$ = new SymbolInfo($1->get_name(), "statement");
	}
	| FOR LPAREN expression_statement expression_statement expression RPAREN statement {
		print_grammar_rule("statement", "FOR LPAREN expression_statement expression_statement expression RPAREN statement");
		$$ = new SymbolInfo("", "statement");
	}
	| IF LPAREN expression RPAREN statement %prec LOWER_THAN_ELSE {
		// how did you resolve the conflict? check at book 189 page
		// The precedence of the token to shift must be higher than the precedence of the rule to reduce, so %nonassoc ELSE must come after %nonassoc THEN or %nonassoc LOWER_THAN_ELSE
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
		if (sym->search($3->get_name(), 'A') == nullptr) {
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
		$$->set_data_type($1->get_data_type()); // result of an expression will have a certain data type, won't it?
	}
	| error SEMICOLON {
		yyclearin; // clear the lookahead token
		yyerrok; // clear the error stack
		show_error(SYNTAX, S_EXP_STATEMENT, "", errorout);
		show_syntax_error();
		$$ = new SymbolInfo("", "expression_statement");
	}
	;
	  
variable : ID {
		print_grammar_rule("variable", "ID");
		$$ = new SymbolInfo($1->get_name(), "VARIABLE", $1->get_data_type());
		
		SymbolInfo* res = sym->search($1->get_name(), 'A');
		if (res == nullptr) {
			show_error(SEMANTIC, UNDECLARED_VARIABLE, $1->get_name(), errorout);
		}
		// else if (res->is_array()) {
		// 	// declared as an array, but used like normal variable, so error
		// 	show_error(SEMANTIC, ARRAY_AS_VAR, $1->get_name(), errorout);
		// }
		// else if (res->is_func_definition() || res->is_func_declaration()) {
		// 	// declared as a function, but used like normal variable, so error
		// 	show_error(SEMANTIC, FUNC_AS_VAR, $1->get_name(), errorout);
		// }
		else {
			$$->set_data_type(res->get_data_type());
			$$->set_array(res->is_array());
		}
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
	}
	;
	 
expression : logic_expression {
		print_grammar_rule("expression", "logic_expression");
		$$ = new SymbolInfo($1->get_name(), "expression");
		$$->set_data_type($1->get_data_type());
		$$->set_array($1->is_array());
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
	}	
	;
			
logic_expression : rel_expression {
		print_grammar_rule("logic_expression", "rel_expression");
		$$ = new SymbolInfo($1->get_name(), "logic_expression");
		$$->set_data_type($1->get_data_type());
		$$->set_array($1->is_array());
	}
	| rel_expression LOGICOP rel_expression {
		print_grammar_rule("logic_expression", "rel_expression LOGICOP rel_expression");
		$$ = new SymbolInfo("", "logic_expression");
		if ($1->get_data_type() == "VOID" || $3->get_data_type() == "VOID") {
			show_error(SEMANTIC, VOID_USAGE, "", errorout);
		}
		else if ($1->get_data_type() == "ERROR" || $3->get_data_type() == "ERROR") {
			show_error(SEMANTIC, TYPE_ERROR, "", errorout);
		}
		else if ($1->get_data_type() == "FLOAT" || $3->get_data_type() == "FLOAT") {
			show_error(WARNING, LOGICAL_FLOAT, "", errorout);
			$$->set_data_type("INT");
		}
		else {
			$$->set_data_type("INT");
		}
	}
	;
			
rel_expression : simple_expression {
		print_grammar_rule("rel_expression", "simple_expression");
		$$ = new SymbolInfo($1->get_name(), "rel_expression");
		$$->set_data_type($1->get_data_type());
		$$->set_array($1->is_array()); // will need in function argument type checking
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
		$$ = new SymbolInfo($1->get_name(), "simple_expression");
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
		$$ = new SymbolInfo($1->get_name(), "term");
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
			else if (is_zero($3->get_name())) {
				show_error(WARNING, MOD_BY_ZERO, "", errorout);
			}
			else {
				$$->set_data_type("INT");
			}
		}
		else if ($2->get_name() == "/") {
			if (is_zero($3->get_name())) {
				show_error(WARNING, DIV_BY_ZERO, "", errorout);
			}
			else if ($1->get_data_type() == "FLOAT" || $3->get_data_type() == "FLOAT") {
				$$->set_data_type("FLOAT");
			}
			else {
				$$->set_data_type("INT");
			}
		}
		else if ($2->get_name() == "*") {
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
		if ($2->get_data_type() == "VOID") {
			show_error(SEMANTIC, VOID_USAGE, "", errorout);
			$$->set_data_type("ERROR");
		}
		else $$->set_data_type($2->get_data_type());
	}
	| NOT unary_expression {
		print_grammar_rule("unary_expression", "ADDOP unary_expression");
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
	}
	| factor {
		print_grammar_rule("unary_expression", "factor");
		$$ = new SymbolInfo($1->get_name(), "unary_expression");
		$$->set_data_type($1->get_data_type());
		$$->set_array($1->is_array());
	}
	;
	
factor : variable {
		print_grammar_rule("factor", "variable");
		$$ = new SymbolInfo($1->get_name(), "factor");
		$$->set_data_type($1->get_data_type());
		$$->set_array($1->is_array());
	}
	| ID LPAREN argument_list RPAREN {
		print_grammar_rule("factor", "ID LPAREN argument_list RPAREN");
		$$ = new SymbolInfo("", "factor");
		// sym->print('A');
		SymbolInfo* res = sym->search($1->get_name(), 'A');
		bool ok = true;
		if (res == nullptr) {
			show_error(SEMANTIC, UNDECLARED_FUNCTION, $1->get_name(), errorout);
			ok = false;
		}
		else if (!res->is_func_declaration() && !res->is_func_definition()) {
			show_error(SEMANTIC, NOT_A_FUNCTION, $1->get_name(), errorout);
			ok = false;
		}
		else if (res->is_func_declaration() && !res->is_func_definition()) {
			show_error(SEMANTIC, UNDEFINED_FUNCTION, $1->get_name(), errorout);
			ok = false;
		}
		else if (res->get_param_list().size() < $3->get_param_list().size()) {
			show_error(SEMANTIC, TOO_MANY_ARGUMENTS, $1->get_name(), errorout);
			ok = false;
		}
		else if (res->get_param_list().size() > $3->get_param_list().size()) {
			show_error(SEMANTIC, TOO_FEW_ARGUMENTS, $1->get_name(), errorout);
			ok = false;
		}
		else {
			vector<SymbolInfo*> now = res->get_param_list();
			vector<SymbolInfo*> they = $3->get_param_list();
			for (int i = 0; i < now.size(); i++) {
				if (now[i]->get_data_type() != they[i]->get_data_type() || now[i]->is_array() != they[i]->is_array()) {
					cerr << "Function: " << res->get_name() << endl;
					cerr << "original: " << now[i]->get_data_type() << " given: " << they[i]->get_data_type() << " name: " << now[i]->get_name() << " line " << line_count << endl;
					string str = to_string(i + 1);
					str += " of \'" + $1->get_name() + "\'";
					show_error(SEMANTIC, ARG_TYPE_MISMATCH, str, errorout);
				}
			}
			$$->set_data_type(res->get_data_type());
		}
	}
	| LPAREN expression RPAREN {
		print_grammar_rule("factor", "LPAREN expression RPAREN");
		$$ = new SymbolInfo($2->get_name(), "factor");
		$$->set_data_type($2->get_data_type());
	}
	| CONST_INT {
		print_grammar_rule("factor", "CONST_INT");
		$$ = new SymbolInfo($1->get_name(), "factor", "INT");
	}
	| CONST_FLOAT {
		print_grammar_rule("factor", "CONST_FLOAT");
		$$ = new SymbolInfo($1->get_name(), "factor", "FLOAT");
	}
	| variable INCOP {
		print_grammar_rule("factor", "variable INCOP");
		$$ = new SymbolInfo("", "factor");
		if ($1->get_data_type() == "VOID") {
			show_error(SEMANTIC, VOID_USAGE, $1->get_name(), errorout);
		}
		else if ($1->get_data_type() == "ERROR") {
			show_error(SEMANTIC, TYPE_ERROR, $1->get_name(), errorout);
		}
		else {
			$$->set_data_type($1->get_data_type());
		}
	}
	| variable DECOP {
		print_grammar_rule("factor", "variable DECOP");
		$$ = new SymbolInfo("", "factor");
		if ($1->get_data_type() == "VOID") {
			show_error(SEMANTIC, VOID_USAGE, "", errorout);
		}
		else if ($1->get_data_type() == "ERROR") {
			show_error(SEMANTIC, TYPE_ERROR, "", errorout);
		}
		else {
			$$->set_data_type($1->get_data_type());
		}
	}
	;
	
argument_list : arguments {
		print_grammar_rule("argument_list", "arguments");
		$$ = new SymbolInfo("", "argument_list");
		$$->set_param_list($1->get_param_list());
	}
	| arguments error {
		print_grammar_rule("argument_list", "arguments");
		yyclearin; // clear the lookahead token
		yyerrok; // start normal parsing again
		show_error(SYNTAX, S_ARG_LIST, "", errorout);
		show_syntax_error();
		$$ = new SymbolInfo("", "argument_list");
		$$->set_param_list($1->get_param_list());
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
		$$->add_param($3);
	}
	| logic_expression {
		print_grammar_rule("arguments", "logic_expression");
		$$ = new SymbolInfo("", "arguments");
		$$->add_param($1);
	}
	;

lcurls : LCURL {
		$$ = $1;
		sym->enter_scope();
		for (SymbolInfo* they : current_function_parameters) {
			if (they->get_name() == "") // nameless, no need to insert
				continue;
			SymbolInfo* another = new SymbolInfo(they->get_name(), they->get_type(), they->get_data_type());
			another->set_array(they->is_array());
			if (!sym->insert(another)) {
				// insertion failed
				show_error(SEMANTIC, PARAM_REDEFINITION, another->get_name(), errorout);
				// in sample output, after any failure, the next arguments are not inserted to the symbol table
				// so we will break the loop
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

	logout << "Total Lines: " << line_count << endl;
	logout << "Total Errors: " << error_count << endl;
	treeout.close();
	errorout.close();
	logout.close();
	
	return 0;
}

