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
vector<Param> current_function_parameters;

ofstream treeout, errorout, logout;

void yyerror(const string& s) {
	logout << "Error at line no " << line_count << " : syntax error" << endl;
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

void reset_current_parameters() { current_function_parameters.clear(); }

void copy_func_parameters(const vector<Param>& param_list) {
	current_function_parameters.clear();
	current_function_parameters = param_list; // no pointer used now, so should be no problem
}

void copy_func_parameters(SymbolInfo* si) {
	copy_func_parameters(si->get_param_list());
}

void insert_function(const string& func_name, const string& type_specifier, const vector<Param>& param_list, bool is_definition) {
	if (is_definition) {
		reset_current_parameters();
		copy_func_parameters(param_list);
	}
	SymbolInfo* function = new SymbolInfo(func_name, "FUNCTION", type_specifier);
	if (is_definition) function->set_func_definition(true);
	else {
		function->set_func_declaration(true);
		function->set_func_definition(false);
	}
	function->set_param_list(param_list);

	if (function->is_func_definition()) {
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
			if (!og_func->is_func_declaration() && !og_func->is_func_definition()) {
				// same name variable already present with this name
				show_error(SEMANTIC, DIFFERENT_REDECLARATION, function->get_name(), errorout);
			}
			else if (og_func->is_func_definition()) {
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
				// defintion param type and declaraion param type mismatch
				vector<Param> og_list = og_func->get_param_list();
				vector<Param> now_list = function->get_param_list();
				for (int i = 0; i < og_list.size(); i++) {
					if (og_list[i].data_type != now_list[i].data_type) {
						show_error(SEMANTIC, CONFLICTING_TYPE, function->get_name(), errorout);
					}
				}
			}
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
			if (!og_func->is_func_declaration() && !og_func->is_func_definition()) {
				// same name variable already present with this name
				show_error(SEMANTIC, DIFFERENT_REDECLARATION, function->get_name(), errorout);
			}
			else if (og_func->is_func_definition() || og_func->is_func_declaration()) {
				// function definition already exists
				show_error(SEMANTIC, FUNC_REDEFINITION, function->get_name(), errorout);
			}
			free_s(function);
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
%}

%nonassoc LOWER_THAN_ELSE
%nonassoc ELSE

%error-verbose

%union {
	SymbolInfo* symbol_info;
}

%token <symbol_info> IF ELSE FOR WHILE DO BREAK RETURN SWITCH CASE DEFAULT CONTINUE PRINTLN ADDOP INCOP DECOP RELOP ASSIGNOP LOGICOP BITOP NOT LPAREN RPAREN LCURL RCURL LSQUARE RSQUARE COMMA SEMICOLON INT CHAR FLOAT DOUBLE VOID
%token <symbol_info> CONST_INT CONST_FLOAT ID MULOP
%type <symbol_info> start program unit var_declaration func_declaration func_definition type_specifier parameter_list compound_statement statements declaration_list statement expression expression_statement logic_expression rel_expression simple_expression term unary_expression factor variable argument_list arguments lcurls

%%

start : program {
		print_grammar_rule("start", "program");
		$$ = new SymbolInfo("", "start");
		free_s($1);
	}
	;

program : program unit {
		print_grammar_rule("program", "program unit");
		$$ = new SymbolInfo("", "program");	
		free_s($1); free_s($2);
	}
	| unit {
		print_grammar_rule("program", "unit");
		$$ = new SymbolInfo("", "program");
		free_s($1);
	}
	;
	
unit : var_declaration {
		print_grammar_rule("unit", "var_declaration");
		$$ = new SymbolInfo("", "unit");
		free_s($1);
	}
    | func_declaration {
		print_grammar_rule("unit", "func_declaration");
		$$ = new SymbolInfo("", "unit");
		free_s($1);
	}
    | func_definition {
		print_grammar_rule("unit", "func_definition");
		$$ = new SymbolInfo("", "unit");
		free_s($1);
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
		reset_current_parameters(); // resetting for this function
		$$ = new SymbolInfo("", "func_declaration");
		insert_function($2->get_name(), $1->get_data_type(), $4->get_param_list(), false);
		free_s($1); free_s($2); free_s($4);
	}
	| type_specifier ID LPAREN error RPAREN SEMICOLON {
		print_grammar_rule("func_declaration", "type_specifier ID LPAREN RPAREN SEMICOLON");
		reset_current_parameters();
		$$ = new SymbolInfo("", "func_declaration");
		insert_function($2->get_name(), $1->get_data_type(), {}, false);
		free_s($1); free_s($2);
	}
	| type_specifier ID LPAREN RPAREN SEMICOLON {
		print_grammar_rule("func_declaration", "type_specifier ID LPAREN RPAREN SEMICOLON");
		reset_current_parameters();
		$$ = new SymbolInfo("", "func_declaration");
		insert_function($2->get_name(), $1->get_data_type(), {}, false);
		free_s($1); free_s($2);
	}
	;
	 
func_definition : type_specifier ID LPAREN parameter_list RPAREN { insert_function($2->get_name(), $1->get_data_type(), $4->get_param_list(), true); } compound_statement {
		print_grammar_rule("func_definition", "type_specifier ID LPAREN parameter_list RPAREN compound_statement");
		$$ = new SymbolInfo("", "func_definition");
		free_s($1); free_s($2); free_s($4); free_s($6);
	}
	| type_specifier ID LPAREN error RPAREN { insert_function($2->get_name(), $1->get_data_type(), {}, true); } compound_statement {
		print_grammar_rule("func_definition", "type_specifier ID LPAREN parameter_list RPAREN compound_statement");
		$$ = new SymbolInfo("", "func_definition");
		show_error(SYNTAX, S_PARAM_FUNC_DEFINITION, "", errorout);
		free_s($1); free_s($2); free_s($6);
	}
	| type_specifier ID LPAREN RPAREN { insert_function($2->get_name(), $1->get_data_type(), {}, true); } compound_statement {
		print_grammar_rule("func_definition", "type_specifier ID LPAREN RPAREN compound_statement");
		$$ = new SymbolInfo("", "func_definition");
		free_s($1); free_s($2); free_s($5);
	}
	;				

parameter_list : parameter_list COMMA type_specifier ID {
		print_grammar_rule("parameter_list", "parameter_list COMMA type_specifier ID");
		$$ = new SymbolInfo("", "parameter_list");
		$$->set_param_list($1->get_param_list());
		$$->add_param($4->get_name(), $3->get_data_type());
		check_type_specifier($3, $4->get_name());
		copy_func_parameters($$);
		free_s($1); free_s($3); free_s($4);
	}
	| parameter_list COMMA type_specifier {
		print_grammar_rule("parameter_list", "parameter_list COMMA type_specifier");
		$$ = new SymbolInfo("", "parameter_list");
		$$->set_param_list($1->get_param_list());
		$$->add_param("", $3->get_data_type()); // later check if this nameless parameter is used in function definition. if yes, then show error
		check_type_specifier($3, "");
		copy_func_parameters($$);
		free_s($1); free_s($3);
	}
	| type_specifier ID {
		print_grammar_rule("parameter_list", "type_specifier ID");
		$$ = new SymbolInfo("", "parameter_list");
		$$->add_param($2->get_name(), $1->get_data_type());
		check_type_specifier($1, $2->get_name());
		copy_func_parameters($$);
		free_s($1); free_s($2);
	}
	| type_specifier {
		print_grammar_rule("parameter_list", "type_specifier");
		$$ = new SymbolInfo("", "parameter_list");
		$$->add_param("", $1->get_data_type()); // later check if this nameless parameter is used in function definition. if yes, then show error
		check_type_specifier($1, "");
		copy_func_parameters($$);
		free_s($1);
	}
	;
	
compound_statement : lcurls statements RCURL {
		print_grammar_rule("compound_statement", "LCURL statements RCURL");
		$$ = new SymbolInfo("", "compound_statement");
		sym->print('A', logout);
		sym->exit_scope();
		free_s($1); free_s($2);
	}
	| lcurls error RCURL {
		print_grammar_rule("compound_statement", "LCURL RCURL");
		$$ = new SymbolInfo("", "compound_statement");
		sym->print('A', logout);
		sym->exit_scope();
		free_s($1);
	}
	| lcurls RCURL {
		print_grammar_rule("compound_statement", "LCURL RCURL");
		$$ = new SymbolInfo("", "compound_statement");
		sym->print('A', logout);
		sym->exit_scope();
		free_s($1);
	}
	;
 		    
var_declaration : type_specifier declaration_list SEMICOLON {
		print_grammar_rule("var_declaration", "type_specifier declaration_list SEMICOLON");
		$$ = new SymbolInfo("", "var_declaration", $1->get_data_type());
		string str = "";
		vector<Param> cur_list = $2->get_param_list();
		for (int i = 0; i < cur_list.size(); i++) {
			str += cur_list[i].name;
			if (i != cur_list.size() - 1) str += ", ";
		}
		bool ok = check_type_specifier($1, str);
		if (ok) {
			for (int i = 0; i < cur_list.size(); i++) {
				// now we will set the data_type of all these symbols to $1
				cur_list[i].data_type = $1->get_data_type();
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
		free_s($1); free_s($2);
	}
	| type_specifier error SEMICOLON {
		print_grammar_rule("var_declaration", "type_specifier declaration_list SEMICOLON");
		$$ = new SymbolInfo("", "var_declaration");
		yyclearin;
		yyerrok;
		show_error(SYNTAX, S_DECL_VAR_DECLARATION, "", errorout);
		free_s($1);
	}
	;
 		 
type_specifier : INT {
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
		$$->set_param_list($1->get_param_list());
		$$->add_param($3->get_name(), "");
		free_s($1); free_s($3);
	}
	| declaration_list COMMA ID LSQUARE CONST_INT RSQUARE {
		print_grammar_rule("declaration_list", "declaration_list COMMA ID LSQUARE CONST_INT RSQUARE");
		$$ = new SymbolInfo("", "declaration_list");
		$$->set_param_list($1->get_param_list());
		$$->add_param($3->get_name(), "ID", true);
		free_s($1); free_s($3); free_s($5);
	}
	| ID {
		print_grammar_rule("declaration_list", "ID");
		$$ = new SymbolInfo("", "declaration_list");
		$$->add_param($1->get_name(), "ID");
		free_s($1);
	}
	| ID LSQUARE CONST_INT RSQUARE {
		print_grammar_rule("declaration_list", "ID LSQUARE CONST_INT RSQUARE");
		$$ = new SymbolInfo("", "declaration_list");
		$$->add_param($1->get_name(), "ID", true);
		free_s($1); free_s($3);
	}
	;
 		  
statements : statement {
		print_grammar_rule("statements", "statement");
		$$ = new SymbolInfo($1->get_name(), "statements");
		free_s($1);
	}
	| statements statement {
		print_grammar_rule("statements", "statements statement");
		$$ = new SymbolInfo($1->get_name(), "statements");
		free_s($1); free_s($2);
	}
	;
	   
statement : var_declaration {
		print_grammar_rule("statement", "var_declaration");
		$$ = new SymbolInfo($1->get_name(), "statement", $1->get_data_type());
		free_s($1);
	}
	| expression_statement {
		print_grammar_rule("statement", "expression_statement");
		$$ = new SymbolInfo($1->get_name(), "statement", $1->get_data_type());
		free_s($1);
	}
	| compound_statement {
		print_grammar_rule("statement", "compound_statement");
		$$ = new SymbolInfo($1->get_name(), "statement", $1->get_data_type());
		free_s($1);
	}
	| FOR LPAREN expression_statement expression_statement expression RPAREN statement {
		print_grammar_rule("statement", "FOR LPAREN expression_statement expression_statement expression RPAREN statement");
		$$ = new SymbolInfo("", "statement");
		free_s($3); free_s($4); free_s($5); free_s($7);
	}
	| IF LPAREN expression RPAREN statement %prec LOWER_THAN_ELSE {
		// how did you resolve the conflict? check at book 189 page
		// The precedence of the token to shift must be higher than the precedence of the rule to reduce, so %nonassoc ELSE must come after %nonassoc THEN or %nonassoc LOWER_THAN_ELSE
		print_grammar_rule("statement", "IF LPAREN expression RPAREN statement");
		$$ = new SymbolInfo("", "statement");
		free_s($3); free_s($5);
	}
	| IF LPAREN expression RPAREN statement ELSE statement {
		print_grammar_rule("statement", "IF LPAREN expression RPAREN statement ELSE statement");
		$$ = new SymbolInfo("", "statement");
		free_s($3); free_s($5); free_s($7);
	}
	| WHILE LPAREN expression RPAREN statement {
		print_grammar_rule("statement", "WHILE LPAREN expression RPAREN statement");
		$$ = new SymbolInfo("", "statement");
		free_s($3); free_s($5);
	}
	| PRINTLN LPAREN ID RPAREN SEMICOLON {
		print_grammar_rule("statement", "PRINTLN LPAREN ID RPAREN SEMICOLON");
		$$ = new SymbolInfo("", "statement");
		if (sym->search($3->get_name(), 'A') == nullptr) {
			show_error(SEMANTIC, UNDECLARED_VARIABLE, $3->get_name(), errorout);
		}
		free_s($3);
	}
	| RETURN expression SEMICOLON {
		print_grammar_rule("statement", "RETURN expression SEMICOLON");
		$$ = new SymbolInfo("", "statement");
		free_s($2);
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
		free_s($1);
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
		
		SymbolInfo* res = sym->search($1->get_name(), 'A');
		if (res == nullptr) {
			show_error(SEMANTIC, UNDECLARED_VARIABLE, $1->get_name(), errorout);
		}
		else {
			$$->set_data_type(res->get_data_type());
			$$->set_array(res->is_array());
		}
		free_s($1);
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
		free_s($1); free_s($3);
	}
	;
	 
expression : logic_expression {
		print_grammar_rule("expression", "logic_expression");
		$$ = new SymbolInfo($1->get_name(), "expression", $1->get_data_type());
		$$->set_array($1->is_array());
		free_s($1);
	}	
	| variable ASSIGNOP logic_expression {
		print_grammar_rule("expression", "variable ASSIGNOP logic_expression");
		$$ = new SymbolInfo("", "expression");
		if ($1->get_data_type() == "VOID" || $3->get_data_type() == "VOID") {
			show_error(SEMANTIC, VOID_USAGE, "", errorout);
			$$->set_data_type("ERROR");
		}
		else if ($1->get_data_type() == "ERROR" || $3->get_data_type() == "ERROR") {
			show_error(SEMANTIC, TYPE_ERROR, "", errorout);
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
		free_s($1); free_s($3);
	}	
	;
			
logic_expression : rel_expression {
		print_grammar_rule("logic_expression", "rel_expression");
		$$ = new SymbolInfo($1->get_name(), "logic_expression", $1->get_data_type());
		$$->set_array($1->is_array());
		free_s($1);
	}
	| rel_expression LOGICOP rel_expression {
		print_grammar_rule("logic_expression", "rel_expression LOGICOP rel_expression");
		$$ = new SymbolInfo("", "logic_expression");
		if ($1->get_data_type() == "VOID" || $3->get_data_type() == "VOID") {
			show_error(SEMANTIC, VOID_USAGE, "", errorout);
			$$->set_data_type("ERROR");
		}
		else if ($1->get_data_type() == "ERROR" || $3->get_data_type() == "ERROR") {
			show_error(SEMANTIC, TYPE_ERROR, "", errorout);
			$$->set_data_type("ERROR");
		}
		else if ($1->get_data_type() == "FLOAT" || $3->get_data_type() == "FLOAT") {
			show_error(WARNING, LOGICAL_FLOAT, "", errorout);
			$$->set_data_type("INT");
		}
		else {
			$$->set_data_type("INT");
		}
		free_s($1); free_s($3);
	}
	;
			
rel_expression : simple_expression {
		print_grammar_rule("rel_expression", "simple_expression");
		$$ = new SymbolInfo($1->get_name(), "rel_expression", $1->get_data_type());
		$$->set_array($1->is_array()); // will need in function argument type checking
		free_s($1);
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
		free_s($1); free_s($3);
	}	
	;
				
simple_expression : term {
		print_grammar_rule("simple_expression", "term");
		$$ = new SymbolInfo($1->get_name(), "simple_expression", $1->get_data_type());
		$$->set_array($1->is_array());
		free_s($1);
	}
	| simple_expression ADDOP term {
		print_grammar_rule("simple_expression", "simple_expression ADDOP term");
		$$ = new SymbolInfo("", "simple_expression");
		if ($1->get_data_type() == "VOID" || $3->get_data_type() == "VOID") {
			show_error(SEMANTIC, VOID_USAGE, "", errorout);
		}
		$$->set_data_type(type_cast($1->get_data_type(), $3->get_data_type()));
		free_s($1); free_s($3);
	}
	;
					
term : unary_expression {
		print_grammar_rule("term", "unary_expression");
		$$ = new SymbolInfo($1->get_name(), "term", $1->get_data_type());
		$$->set_array($1->is_array());
		free_s($1);
	}
	| term MULOP unary_expression {
		print_grammar_rule("term", "term MULOP unary_expression");
		$$ = new SymbolInfo("", "term");
		if ($1->get_data_type() == "VOID" || $3->get_data_type() == "VOID") {
			show_error(SEMANTIC, VOID_USAGE, "", errorout);
			$$->set_data_type("ERROR");
		}
		else if ($1->get_data_type() == "ERROR" || $3->get_data_type() == "ERROR") {
			show_error(SEMANTIC, TYPE_ERROR, "", errorout);
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
		free_s($1); free_s($2); free_s($3);
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
		free_s($2);
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
		free_s($2);
	}
	| factor {
		print_grammar_rule("unary_expression", "factor");
		$$ = new SymbolInfo($1->get_name(), "unary_expression", $1->get_data_type());
		$$->set_array($1->is_array());
		free_s($1);
	}
	;
	
factor : variable {
		print_grammar_rule("factor", "variable");
		$$ = new SymbolInfo($1->get_name(), "factor", $1->get_data_type());
		$$->set_array($1->is_array());
		free_s($1);
	}
	| ID LPAREN argument_list RPAREN {
		print_grammar_rule("factor", "ID LPAREN argument_list RPAREN");
		$$ = new SymbolInfo("", "factor");
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
		free_s($1); free_s($3);
	}
	| LPAREN expression RPAREN {
		print_grammar_rule("factor", "LPAREN expression RPAREN");
		$$ = new SymbolInfo($2->get_name(), "factor", $2->get_data_type());
		free_s($2);
	}
	| CONST_INT {
		print_grammar_rule("factor", "CONST_INT");
		$$ = new SymbolInfo($1->get_name(), "factor", "INT");
		free_s($1);
	}
	| CONST_FLOAT {
		print_grammar_rule("factor", "CONST_FLOAT");
		$$ = new SymbolInfo($1->get_name(), "factor", "FLOAT");
		free_s($1);
	}
	| variable INCOP {
		print_grammar_rule("factor", "variable INCOP");
		$$ = new SymbolInfo("", "factor");
		if ($1->get_data_type() == "VOID") {
			show_error(SEMANTIC, VOID_USAGE, $1->get_name(), errorout);
			$$->set_data_type("ERROR");
		}
		else if ($1->get_data_type() == "ERROR") {
			show_error(SEMANTIC, TYPE_ERROR, $1->get_name(), errorout);
			$$->set_data_type("ERROR");
		}
		else {
			$$->set_data_type($1->get_data_type());
		}
		free_s($1);
	}
	| variable DECOP {
		print_grammar_rule("factor", "variable DECOP");
		$$ = new SymbolInfo("", "factor");
		if ($1->get_data_type() == "VOID") {
			show_error(SEMANTIC, VOID_USAGE, "", errorout);
			$$->set_data_type("ERROR");
		}
		else if ($1->get_data_type() == "ERROR") {
			show_error(SEMANTIC, TYPE_ERROR, "", errorout);
			$$->set_data_type("ERROR");
		}
		else {
			$$->set_data_type($1->get_data_type());
		}
		free_s($1);
	}
	;
	
argument_list : arguments {
		print_grammar_rule("argument_list", "arguments");
		$$ = new SymbolInfo("", "argument_list");
		$$->set_param_list($1->get_param_list());
		free_s($1);
	}
	| arguments error {
		print_grammar_rule("argument_list", "arguments");
		yyclearin; // clear the lookahead token
		yyerrok; // start normal parsing again
		show_error(SYNTAX, S_ARG_LIST, "", errorout);
		$$ = new SymbolInfo("", "argument_list");
		$$->set_param_list($1->get_param_list());
		free_s($1);
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
		free_s($1); free_s($3);
	}
	| logic_expression {
		print_grammar_rule("arguments", "logic_expression");
		$$ = new SymbolInfo("", "arguments");
		$$->add_param($1->get_name(), $1->get_data_type(), $1->is_array());
		free_s($1);
	}
	;

lcurls : LCURL {
		$$ = new SymbolInfo("", "LCURLS");
		sym->enter_scope();
		// why am I inserting symbols here? so that the parameters can be recognized in the newly created scope
		// but remember, in case of function prototypes, even though I am not inserting the symbols, I am still checking in 
		// insert_function() whether two non-empty names are same or not
		for (const Param& they : current_function_parameters) {
			if (they.name == "") {// nameless, no need to insert 
				show_error(SYNTAX, S_PARAM_NAMELESS, "", errorout);
				continue;
			}
			SymbolInfo* another = new SymbolInfo(they.name, "ID", they.data_type);
			another->set_array(they.is_array);
			if (!sym->insert(another)) {
				// insertion failed
				show_error(SEMANTIC, PARAM_REDEFINITION, another->get_name(), errorout);
				// in sample output, after any failure, the next arguments are not inserted to the symbol table
				// so we will break the loop
				delete another;
				break;
			}
		}
		reset_current_parameters();
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
	reset_current_parameters();

	logout << "Total Lines: " << line_count << endl;
	logout << "Total Errors: " << error_count << endl;
	treeout.close();
	errorout.close();
	logout.close();
	return 0;
}

