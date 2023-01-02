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
			for (int i = 0; i < now_list.size(); i++) {
				for (int j = i + 1; j < now_list.size(); j++) {
					// checking if any two parameters have same name
					if (now_list[i]->get_name() == now_list[j]->get_name()) {
						show_error(SEMANTIC, PARAM_REDEFINITION, function->get_name(), errorout);
					}
				}
			}
		}
	}
}

void check_type_specifier(SymbolInfo* symbol) {
	if (symbol->get_data_type() == "VOID") {
		show_error(SEMANTIC, VOID_TYPE, symbol->get_name(), errorout);
	}
}
%}

%union {
	SymbolInfo* symbol_info;
}

%token <symbol_info> IF ELSE FOR WHILE DO BREAK INT CHAR FLOAT DOUBLE VOID RETURN SWITCH CASE DEFAULT CONTINUE PRINTF PRINTLN CONST_INT CONST_FLOAT ID ADDOP MULOP INCOP DECOP RELOP ASSIGNOP LOGICOP BITOP NOT LPAREN RPAREN LCURL RCURL LTHIRD RTHIRD COMMA SEMICOLON
%type <symbol_info> start program unit var_declaration func_declaration func_definition type_specifier parameter_list compound_statement statements declaration_list statement expression_statement logic_expression rel_expression simple_expression term unary_expression factor variable argument_list arguments

%%

start : program {
		print_grammar_rule("start", "program");
		$$ = new SymbolInfo("start");
	}
	;

program : program unit {
		print_grammar_rule("program", "program unit");
		$$ = new SymbolInfo("program");	
	}
	| unit {
		print_grammar_rule("program", "unit");
		$$ = new SymbolInfo("program");
	}
	;
	
unit : var_declaration {
		print_grammar_rule("unit", "var_declaration");
		$$ = new SymbolInfo("unit");
	}
    | func_declaration {
		print_grammar_rule("unit", "func_declaration");
		$$ = new SymbolInfo("unit");
	}
    | func_definition {
		print_grammar_rule("unit", "func_definition");
		$$ = new SymbolInfo("unit");
	}
    ;
     
func_declaration : type_specifier ID LPAREN parameter_list RPAREN SEMICOLON {
		print_grammar_rule("func_declaration", "type_specifier ID LPAREN parameter_list RPAREN SEMICOLON");
		$$ = new SymbolInfo("func_declaration");
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
	| type_specifier ID LPAREN RPAREN SEMICOLON {
		print_grammar_rule("func_declaration", "type_specifier ID LPAREN parameter_list RPAREN SEMICOLON");
		$$ = new SymbolInfo("func_declaration");
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
		$$ = new SymbolInfo("func_definition");
	}
	| type_specifier ID LPAREN RPAREN { insert_function($2, $1->get_data_type(), $4->get_param_list()); } compound_statement {
		print_grammar_rule("func_definition", "type_specifier ID LPAREN RPAREN compound_statement");
		$$ = new SymbolInfo("func_definition");
	}
	;				

parameter_list : parameter_list COMMA type_specifier ID {
		print_grammar_rule("parameter_list", "parameter_list COMMA type_specifier ID");
		$$ = new SymbolInfo("parameter_list");
		SymbolInfo* new_param = new SymbolInfo($4->get_name(), "ID", $3->get_data_type());
		$$->set_param_list($1->get_param_list());
		$$->add_param(new_param);
		check_type_specifier($3);
	}
	| parameter_list COMMA type_specifier {
		print_grammar_rule("parameter_list", "parameter_list COMMA type_specifier");
		$$ = new SymbolInfo("parameter_list");
		SymbolInfo* new_param = new SymbolInfo("", "ID", $3->get_data_type()); // later check if this nameless parameter is used in function definition. if yes, then show error
		$$->set_param_list($1->get_param_list());
		$$->add_param(new_param);
		check_type_specifier($3);
	}
	| type_specifier ID {
		print_grammar_rule("parameter_list", "type_specifier ID");
		$$ = new SymbolInfo("parameter_list");
		SymbolInfo* new_param = new SymbolInfo($2->get_name(), "ID", $1->get_data_type());
		$$->add_param(new_param);
		check_type_specifier($1);
	}
	| type_specifier {
		print_grammar_rule("parameter_list", "type_specifier");
		$$ = new SymbolInfo("parameter_list");
		SymbolInfo* new_param = new SymbolInfo("", "ID", $1->get_data_type()); // later check if this nameless parameter is used in function definition. if yes, then show error
		$$->add_param(new_param);
		check_type_specifier($1);
	}
	;

 		
compound_statement : LCURL statements RCURL
 		    | LCURL RCURL
 		    ;
 		    
var_declaration : type_specifier declaration_list SEMICOLON
 		 ;
 		 
type_specifier	: INT
				{
				}
 		| FLOAT
 		| VOID
 		;
 		
declaration_list : declaration_list COMMA ID
 		  | declaration_list COMMA ID LTHIRD CONST_INT RTHIRD
 		  | ID
 		  | ID LTHIRD CONST_INT RTHIRD
 		  ;
 		  
statements : statement
	   | statements statement
	   ;
	   
statement : var_declaration
	  | expression_statement
	  | compound_statement
	  | FOR LPAREN expression_statement expression_statement expression RPAREN statement
	  | IF LPAREN expression RPAREN statement
	  | IF LPAREN expression RPAREN statement ELSE statement
	  | WHILE LPAREN expression RPAREN statement
	  | PRINTLN LPAREN ID RPAREN SEMICOLON
	  | RETURN expression SEMICOLON
	  ;
	  
expression_statement 	: SEMICOLON			
			| expression SEMICOLON 
			;
	  
variable : ID 		
	 | ID LTHIRD expression RTHIRD 
	 ;
	 
 expression : logic_expression	
	   | variable ASSIGNOP logic_expression 	
	   ;
			
logic_expression : rel_expression 	
		 | rel_expression LOGICOP rel_expression 	
		 ;
			
rel_expression	: simple_expression 
		| simple_expression RELOP simple_expression	
		;
				
simple_expression : term 
		  | simple_expression ADDOP term 
		  ;
					
term :	unary_expression
     |  term MULOP unary_expression
     ;

unary_expression : ADDOP unary_expression  
		 | NOT unary_expression 
		 | factor 
		 ;
	
factor	: variable 
	| ID LPAREN argument_list RPAREN
	| LPAREN expression RPAREN
	| CONST_INT 
	| CONST_FLOAT
	| variable INCOP 
	| variable DECOP
	;
	
argument_list : arguments
			  |
			  ;
	
arguments : arguments COMMA logic_expression
	      | logic_expression
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

