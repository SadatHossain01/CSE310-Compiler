%{
#include <iostream>
#include <cstdlib>
#include <cstring>
#include <string>
#include <cmath>
#include <vector>
#include <cassert>
#include "symbol_table.h"

using namespace std;

#define BUCKET_SIZE 10

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

	bool success = sym->insert(function);
	if (success) return; // no function definition available, so insert it as it is

	SymbolInfo* prev_func = sym->search(function->get_name());
	assert(prev_func != nullptr); // some prev instance must be there, otherwise success would be true

	if (!prev_func->is_func_declaration()) {
		// so it has been already defined either as a function or as an identifier
		errorout << "Line# " << line_count << ": Redefinition of parameter \'" << function->get_name() << "\'" << endl;
		error_count++;
	}
	else {
		// previous one was a prototype
		if (prev_func->get_data_type() != type_specifier) {
			errorout << "Line# " << line_count << ": Conflicting types for \'" << function->get_name() << "\'" << endl;
			error_count++;
		}
		else if (prev_func->get_param_list().size() != param_list.size()) {
			errorout << "Line# " << line_count << ": Conflicting types for \'" << function->get_name() << "\'" << endl;
			error_count++;
		}
		else {
			vector<SymbolInfo*> prev_list = prev_func->get_param_list();
			vector<SymbolInfo*> now_list = function->get_param_list();
			for (int i = 0; i < prev_list.size(); i++) {
				if (prev_list[i]->get_data_type() != now_list[i]->get_data_type()) {
					;
				}
			}
		}
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
		$2->set_data_type($1->get_data_type());

		bool success = sym->insert($2);
		if (!success) {
			errorout << "Line# " << line_count << ": Redefinition of parameter \'" << $2->get_name() << "\'" << endl;
			error_count++;
		}
	}
	| type_specifier ID LPAREN RPAREN SEMICOLON {
		print_grammar_rule("func_declaration", "type_specifier ID LPAREN parameter_list RPAREN SEMICOLON");
		$$ = new SymbolInfo("func_declaration");
		$2->set_func_declaration(true);
		$2->set_data_type($1->get_data_type());

		bool success = sym->insert($2);
		if (!success) {
			errorout << "Line# " << line_count << ": Redefinition of parameter \'" << $2->get_name() << "\'" << endl;
			error_count++;
		}
	}
	;
		 
func_definition : type_specifier ID LPAREN parameter_list RPAREN {} compound_statement {

	}
	| type_specifier ID LPAREN RPAREN compound_statement
	;				


parameter_list  : parameter_list COMMA type_specifier ID
		| parameter_list COMMA type_specifier
 		| type_specifier ID
		| type_specifier
 		;

 		
compound_statement : LCURL statements RCURL
 		    | LCURL RCURL
 		    ;
 		    
var_declaration : type_specifier declaration_list SEMICOLON
 		 ;
 		 
type_specifier	: INT
				{
					print_grammar_rule("type_specifier", "INT");
					$$ = new SymbolInfo("INT", "keyword");
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

