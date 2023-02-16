%{
#include <iostream>
#include <cstdlib>
#include <cstring>
#include <string>
#include <cmath>
#include <vector>
#include <cassert>
#include <map>
#include "utilities.h"
#include "icg_util.h"
#include "symbol_table.h"

using namespace std;

#define BUCKET_SIZE 11

extern int line_count, error_count;
int syntax_error_line, current_offset = 0, label_count = 1, printed_line_count = 0;
int temp_file_lc = 1;
string func_return_type;
SymbolTable *sym;
extern FILE* yyin;
vector<Param> current_function_parameters;
SymbolInfo* expression;
map<int, string> label_map;

ofstream treeout, errorout, logout;
ofstream codeout, tempout; // keep writing data segment in codeout, code segment in tempout, lastly merge both in codeout
void yyerror(const string& s) {
    logout << "Error at line no " << line_count << " : syntax error" << "\n";
    syntax_error_line = line_count;
}
int yyparse(void);
int yylex(void);

string newLabel() {
	string label = "L" + to_string(label_count);
	label_count++;
	return label;
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
	free_s($$);
} <symbol_info>

%token <symbol_info> IF ELSE FOR WHILE DO BREAK RETURN SWITCH CASE DEFAULT CONTINUE PRINTLN ADDOP INCOP DECOP RELOP ASSIGNOP LOGICOP BITOP NOT LPAREN RPAREN LCURL RCURL LSQUARE RSQUARE COMMA SEMICOLON INT CHAR FLOAT DOUBLE VOID CONST_INT CONST_FLOAT ID MULOP
%type <symbol_info> start program unit var_declaration func_declaration func_definition type_specifier parameter_list compound_statement statements declaration_list statement expression expression_statement logic_expression rel_expression simple_expression term unary_expression factor variable argument_list arguments LCURL_ M N unary_boolean

%%

start : { 
		init_icg(); 
	} program {
		print_grammar_rule("start", "program");
		$$ = new SymbolInfo("", "start");
		$$->set_rule("start : program");
		$$->add_child($2);
		$$->print_tree_node(treeout);
		tempout << "\tMOV AX, 4CH\r\n\tINT 21H\r\nMAIN ENDP\r\n";
		temp_file_lc += 3;
		generate_printing_function();
		generate_final_assembly();
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
		$$->set_rule("unit : error");
		$$->set_line(syntax_error_line, syntax_error_line);
		$$->set_terminal(true);
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
		print_grammar_rule("func_declaration", "type_specifier ID LPAREN parameter_list RPAREN SEMICOLON");
		current_function_parameters.clear();
		$$ = new SymbolInfo("", "func_declaration");
		insert_function($2->get_name(), $1->get_data_type(), {}, false);
		$$->set_rule("func_declaration : type_specifier ID LPAREN RPAREN SEMICOLON");
		SymbolInfo* error_token = create_error_token("parameter_list : error", syntax_error_line);
		$$->add_child($1); $$->add_child($2); $$->add_child($3); $$->add_child(error_token); $$->add_child($5); $$->add_child($6);
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
	 
func_definition : type_specifier ID LPAREN parameter_list RPAREN { 
			func_return_type = $1->get_data_type(); 
			insert_function($2->get_name(), $1->get_data_type(), $4->get_param_list(), true); 
			current_function_parameters.clear();
        	current_function_parameters = $4->get_param_list();
		} 
		compound_statement {
		print_grammar_rule("func_definition", "type_specifier ID LPAREN parameter_list RPAREN compound_statement");
		$$ = new SymbolInfo("", "func_definition");
		$$->set_rule("func_definition : type_specifier ID LPAREN parameter_list RPAREN compound_statement");
		$$->add_child($1); $$->add_child($2); $$->add_child($3); $$->add_child($4); $$->add_child($5); $$->add_child($7);
	}
	| type_specifier ID LPAREN error RPAREN { func_return_type = $1->get_data_type(); } compound_statement {
		// not inserting the function if any error occurs in parameter list
		print_grammar_rule("func_definition", "type_specifier ID LPAREN parameter_list RPAREN compound_statement");
		$$ = new SymbolInfo("", "func_definition");
		show_error(SYNTAX, S_PARAM_FUNC_DEFINITION, "", errorout, syntax_error_line);
		SymbolInfo* error_token = create_error_token("parameter_list : error", syntax_error_line);
		$$->set_rule("func_definition : type_specifier ID LPAREN parameter_list RPAREN compound_statement");
		$$->add_child($1); $$->add_child($2); $$->add_child($3); $$->add_child(error_token); $$->add_child($5); $$->add_child($7);
	}
	| type_specifier ID LPAREN RPAREN { 
			func_return_type = $1->get_data_type();
			insert_function($2->get_name(), $1->get_data_type(), {}, true);
			current_function_parameters.clear();
		} 
		compound_statement {
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
	
compound_statement : LCURL_ statements RCURL {
		print_grammar_rule("compound_statement", "LCURL statements RCURL");
		$$ = new SymbolInfo("", "compound_statement");
		sym->print('A', logout);
		$$->set_rule("compound_statement : LCURL statements RCURL");
		$$->add_child($1); $$->add_child($2); $$->add_child($3);

		// let, base offset of current scope is 6, meaning 3 variables declared in previous scope
		// so, if we want to assign an offset to the next variable, it should be 8
		// hence, we need to set the current_scope to the base offset of the latest one
		int prev_offset = current_offset;
		current_offset = sym->get_current_scope()->get_base_offset(); 
		if (prev_offset != current_offset) generate_code("ADD SP, " + to_string(prev_offset - current_offset));
		sym->exit_scope();
	}
	| LCURL_ error RCURL {
		print_grammar_rule("compound_statement", "LCURL RCURL");
		$$ = new SymbolInfo("", "compound_statement");
		sym->print('A', logout);
		$$->set_rule("compound_statement : LCURL RCURL");
		$$->add_child($1); $$->add_child($3);

		int prev_offset = current_offset;
		current_offset = sym->get_current_scope()->get_base_offset(); 
		if (prev_offset != current_offset) generate_code("ADD SP, " + to_string(prev_offset - current_offset));
		sym->exit_scope();
	}
	| LCURL_ RCURL {
		print_grammar_rule("compound_statement", "LCURL RCURL");
		$$ = new SymbolInfo("", "compound_statement");
		sym->print('A', logout);
		$$->set_rule("compound_statement : LCURL RCURL");
		$$->add_child($1); $$->add_child($2);
		
		int prev_offset = current_offset;
		current_offset = sym->get_current_scope()->get_base_offset(); 
		if (prev_offset != current_offset) generate_code("ADD SP, " + to_string(prev_offset - current_offset));
		sym->exit_scope();
	}
	;
 		    
var_declaration : type_specifier declaration_list SEMICOLON {
		print_grammar_rule("var_declaration", "type_specifier declaration_list SEMICOLON");
		$$ = new SymbolInfo("", "var_declaration", $1->get_data_type());
		insert_symbols($1->get_data_type(), $2->get_param_list(), sym->get_current_scope()->get_id() == 1); // offset assigning will also be done there
		$$->set_rule("var_declaration : type_specifier declaration_list SEMICOLON");
		$$->add_child($1); $$->add_child($2); $$->add_child($3);
	}
	| type_specifier declaration_list error SEMICOLON {
		print_grammar_rule("var_declaration", "type_specifier declaration_list SEMICOLON");	
		$$ = new SymbolInfo("", "var_declaration", $1->get_data_type());
		insert_symbols($1->get_data_type(), $2->get_param_list(), sym->get_current_scope()->get_id() == 1); // offset assigning will also be done there
		show_error(SYNTAX, S_DECL_VAR_DECLARATION, "", errorout, syntax_error_line);
		$$->set_rule("var_declaration : type_specifier declaration_list SEMICOLON");
		$$->add_child($1); $$->add_child($2); $$->add_child($4);

	}
	| type_specifier error SEMICOLON {
		print_grammar_rule("var_declaration", "type_specifier declaration_list SEMICOLON");
		$$ = new SymbolInfo("", "var_declaration", $1->get_data_type());
		show_error(SYNTAX, S_DECL_VAR_DECLARATION, "", errorout, syntax_error_line);
		$$->set_rule("var_declaration : type_specifier declaration_list SEMICOLON");
		SymbolInfo* error_token = create_error_token("declaration_list : error", syntax_error_line);
		$$->add_child($1); $$->add_child(error_token); $$->add_child($3);
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
		$$->add_param(Param($3->get_name(), "ID", true, stoi($5->get_name())));
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
		$$->add_param(Param($1->get_name(), "ID", true, stoi($3->get_name())));
		$$->set_rule("declaration_list : ID LSQUARE CONST_INT RSQUARE");
		$$->add_child($1); $$->add_child($2); $$->add_child($3); $$->add_child($4);
	}
	;
 		  
statements : statement {
		print_grammar_rule("statements", "statement");
		$$ = new SymbolInfo($1->get_name(), "statements");
		$$->set_rule("statements : statement");
		$$->add_child($1);
		$$->set_nextlist($1->get_nextlist());
	}
	| statements M statement {
		print_grammar_rule("statements", "statements statement");
		$$ = new SymbolInfo($1->get_name(), "statements");
		$$->set_rule("statements : statements statement");
		$$->add_child($1); $$->add_child($3);
		backpatch($1->get_nextlist(), $2->get_label());
		$$->set_nextlist($3->get_nextlist());
		delete $2;
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
	| IF LPAREN expression unary_boolean RPAREN M statement %prec THEN {
		// use the precedence of THEN here
		print_grammar_rule("statement", "IF LPAREN expression RPAREN statement %prec THEN");
		$$ = new SymbolInfo("", "statement");
		$$->set_rule("statement : IF LPAREN expression RPAREN statement");
		$$->add_child($1); $$->add_child($2); $$->add_child($3); $$->add_child($5); $$->add_child($7);

		// icg code
		$$->set_nextlist(merge($3->get_falselist(), $7->get_nextlist()));
		backpatch($3->get_truelist(), $6->get_label());
		delete $6;
	}
	| IF LPAREN expression unary_boolean RPAREN M statement ELSE N M statement {
		print_grammar_rule("statement", "IF LPAREN expression RPAREN statement ELSE statement");
		$$ = new SymbolInfo("", "statement");
		$$->set_rule("statement : IF LPAREN expression RPAREN statement ELSE statement");
		$$->add_child($1); $$->add_child($2); $$->add_child($3); $$->add_child($5); $$->add_child($7); $$->add_child($8); $$->add_child($11);

		// icg code
		backpatch($3->get_truelist(), $6->get_label());
		backpatch($3->get_falselist(), $10->get_label());
		$$->set_nextlist(merge(merge($7->get_nextlist(), $9->get_nextlist()), $11->get_nextlist()));
		delete $6; delete $9; delete $10;
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
		int offset = sym->search($3->get_name(), 'A')->get_stack_offset();
		print_id(get_variable_address($3->get_name(), offset));
	}
	| RETURN expression SEMICOLON {
		print_grammar_rule("statement", "RETURN expression SEMICOLON");
		$$ = new SymbolInfo("", "statement");
		$$->set_rule("statement : RETURN expression SEMICOLON");
		$$->add_child($1); $$->add_child($2); $$->add_child($3);
		// adding return type check here
		if (func_return_type == "VOID") {
			show_error(SEMANTIC, RETURNING_IN_VOID, "", errorout);
		}
		else if (func_return_type == "INT" && $2->get_data_type() == "FLOAT") {
			show_error(WARNING, FLOAT_TO_INT, "", errorout);
		}
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
		$$->set_data_type($1->get_data_type()); // result of an expression will have a certain data type
		$$->set_rule("expression_statement : expression SEMICOLON");
		$$->add_child($1); $$->add_child($2);
	}
	| error SEMICOLON {
		show_error(SYNTAX, S_EXP_STATEMENT, "", errorout, syntax_error_line);
		$$ = new SymbolInfo("", "expression_statement");
		$$->set_rule("expression_statement : expression SEMICOLON");
		SymbolInfo* error_token = create_error_token("expression : error", syntax_error_line);
		$$->add_child(error_token); $$->add_child($2);
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
			$$->set_stack_offset(res->get_stack_offset()); // will need stack offset for assignment to variable (and inc, dec operations)
		}
		$$->set_rule("variable : ID");
		$$->add_child($1);
	}	
	| ID LSQUARE expression RSQUARE {
		print_grammar_rule("variable", "ID LSQUARE expression RSQUARE");
		$$ = new SymbolInfo($1->get_name(), "VARIABLE", $1->get_data_type());
		
		SymbolInfo* res = sym->search($1->get_name(), 'A');
		// it has to be an array now
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
			$$->set_type("FROM_ARRAY");
			$$->set_stack_offset(res->get_stack_offset()); 
			generate_code("MOV CX, AX"); // save the index in CX
		}
		$$->set_rule("variable : ID LSQUARE expression RSQUARE");
		$$->add_child($1); $$->add_child($2); $$->add_child($3); $$->add_child($4);
	}
	;
	 
expression : logic_expression {
		print_grammar_rule("expression", "logic_expression");
		$$ = new SymbolInfo($1->get_name(), "expression", $1->get_data_type());
		$$->set_array($1->is_array());
		$$->set_truelist($1->get_truelist());
		$$->set_falselist($1->get_falselist());
		$$->set_nextlist($1->get_nextlist());
		$$->set_rule("expression : logic_expression");
		$$->add_child($1);
		$$->set_exp_evaluated($1->is_exp_evaluated());
		expression = $$;
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

			// icg code
			$$->set_truelist($3->get_truelist());
			$$->set_falselist($3->get_falselist());
			$$->set_nextlist($3->get_nextlist());
			if (!$$->get_truelist().empty() || !$$->get_falselist().empty() || !$$->get_nextlist().empty()) {
				// this is a boolean expression
				backpatch($3->get_truelist(), "L" + to_string(label_count));
				backpatch($3->get_falselist(), "L" + to_string(label_count + 1));
				print_label(label_count++);
				generate_code("MOV AX, 1");
				generate_code("JMP L" + to_string(label_count + 1));
				print_label(label_count++);
				generate_code("XOR AX, AX");
				print_label(label_count++);
			}
			if ($1->get_type() != "FROM_ARRAY") {
				generate_code("MOV " + get_variable_address($1) + ", AX");
			}
			else {
				// so this is an array element
				if ($1->get_stack_offset() == -1) {
					// element of some global array
					generate_code("LEA SI, " + $1->get_name());
					generate_code("SHL CX, 1");
					generate_code("ADD SI, CX");
					generate_code("MOV [SI], AX");
				}
				else {
					// element of some local array, index is in CX
					generate_code("SHL CX, 1");
					generate_code("ADD CX, " + to_string($1->get_stack_offset()));
					generate_code("MOV DI, BP");
					generate_code("SUB DI, CX");
					generate_code("MOV [DI], AX");
				}
				$$->set_exp_evaluated($3->is_exp_evaluated());
			}
		}
		else {
			$$->set_data_type("FLOAT");
		}
		$$->set_rule("expression : variable ASSIGNOP logic_expression");
		$$->add_child($1); $$->add_child($2); $$->add_child($3);
		expression = $$;
	}	
	;
			
logic_expression : rel_expression {
		print_grammar_rule("logic_expression", "rel_expression");
		$$ = new SymbolInfo($1->get_name(), "logic_expression", $1->get_data_type());
		$$->set_array($1->is_array());
		$$->set_truelist($1->get_truelist());
		$$->set_falselist($1->get_falselist());
		$$->set_nextlist($1->get_nextlist());
		$$->set_exp_evaluated($1->is_exp_evaluated());
		$$->set_rule("logic_expression : rel_expression");
		$$->add_child($1);
	}
	| rel_expression {
		// generate_code("MOV BX, AX"); // so that the second operand can be written to AX
		push_to_stack("AX");
	} LOGICOP M rel_expression {
		print_grammar_rule("logic_expression", "rel_expression LOGICOP rel_expression");
		$$ = new SymbolInfo("", "logic_expression");
		if ($1->get_data_type() == "VOID" || $5->get_data_type() == "VOID") {
			show_error(SEMANTIC, VOID_USAGE, "", errorout);
			$$->set_data_type("ERROR");
		}
		else if ($1->get_data_type() == "ERROR" || $5->get_data_type() == "ERROR") {
			// show_error(SEMANTIC, TYPE_ERROR, "", errorout);
			$$->set_data_type("ERROR");
		}
		else if ($1->get_data_type() == "FLOAT" || $5->get_data_type() == "FLOAT") {
			show_error(WARNING, LOGICAL_FLOAT, "", errorout);
			$$->set_data_type("INT");
		}
		else {
			$$->set_data_type("INT");

			// icg code
			generate_code("POP BX");
			if ($3->get_name() == "&&") {
				$$->set_falselist(merge($1->get_falselist(), $5->get_falselist()));
				$$->set_truelist($5->get_truelist());
				backpatch($1->get_truelist(), $4->get_label());
			}
			else if ($3->get_name() == "||") {
				$$->set_truelist(merge($1->get_truelist(), $5->get_truelist()));
				$$->set_falselist($5->get_falselist());
				backpatch($1->get_falselist(), $4->get_label());
			}
		}
		$$->set_rule("logic_expression : rel_expression LOGICOP rel_expression");
		delete $4;
		$$->add_child($1); $$->add_child($3); $$->add_child($5);
	}
	;
			
rel_expression : simple_expression {
		print_grammar_rule("rel_expression", "simple_expression");
		$$ = new SymbolInfo($1->get_name(), "rel_expression", $1->get_data_type());
		$$->set_array($1->is_array()); // will need in function argument type checking
		$$->set_rule("rel_expression : simple_expression");
		$$->add_child($1);
		$$->set_exp_evaluated($1->is_exp_evaluated());

		// icg code
		$$->set_truelist($1->get_truelist());
		$$->set_falselist($1->get_falselist());
		$$->set_nextlist($1->get_nextlist());
		$$->set_exp_evaluated($1->is_exp_evaluated());
	}
	| simple_expression {
		// generate_code("MOV BX, AX"); // so that the second operand can be written to AX
		push_to_stack("AX");
	} RELOP simple_expression {
		print_grammar_rule("rel_expression", "simple_expression RELOP simple_expression");
		$$ = new SymbolInfo("", "rel_expression");
		if ($1->get_data_type() == "VOID" || $4->get_data_type() == "VOID") {
			show_error(SEMANTIC, VOID_USAGE, "", errorout);
			$$->set_data_type("ERROR");
		}
		else {
			$$->set_data_type("INT"); // result of any comparison should be boolean in fact
		}
		$$->set_rule("rel_expression : simple_expression RELOP simple_expression");
		$$->add_child($1); $$->add_child($3); $$->add_child($4);

		// icg code
		generate_code("POP BX");
		generate_relop_code($3->get_name(), $$);
		$$->set_exp_evaluated(true);
	}	
	;
				
simple_expression : term {
		print_grammar_rule("simple_expression", "term");
		$$ = new SymbolInfo($1->get_name(), "simple_expression", $1->get_data_type());
		$$->set_array($1->is_array());
		$$->set_rule("simple_expression : term");
		$$->add_child($1);

		// icg code
		$$->set_truelist($1->get_truelist());
		$$->set_falselist($1->get_falselist());
		$$->set_nextlist($1->get_nextlist());
		$$->set_exp_evaluated($1->is_exp_evaluated());
	}
	| simple_expression {
		// generate_code("MOV BX, AX"); // so that the second operand can be written to AX
		push_to_stack("AX");
	} ADDOP term {
		print_grammar_rule("simple_expression", "simple_expression ADDOP term");
		$$ = new SymbolInfo("", "simple_expression");
		if ($1->get_data_type() == "VOID" || $4->get_data_type() == "VOID") {
			show_error(SEMANTIC, VOID_USAGE, "", errorout);
		}
		$$->set_data_type(type_cast($1->get_data_type(), $4->get_data_type()));
		$$->set_rule("simple_expression : simple_expression ADDOP term");
		$$->add_child($1); $$->add_child($3); $$->add_child($4);

		// icg code
		generate_code("POP BX");
		generate_addop_code($3->get_name());
	}
	;
					
term : unary_expression {
		print_grammar_rule("term", "unary_expression");
		$$ = new SymbolInfo($1->get_name(), "term", $1->get_data_type());
		$$->set_array($1->is_array());
		$$->set_rule("term : unary_expression");
		$$->add_child($1);

		// icg code
		$$->set_truelist($1->get_truelist());
		$$->set_falselist($1->get_falselist());
		$$->set_nextlist($1->get_nextlist());
		$$->set_exp_evaluated($1->is_exp_evaluated());
	}
	| term { 
		// generate_code("MOV BX, AX"); // so that the second operand can be written to AX
		push_to_stack("AX");
	} MULOP unary_expression {
		print_grammar_rule("term", "term MULOP unary_expression");
		$$ = new SymbolInfo("", "term");
		if ($1->get_data_type() == "VOID" || $4->get_data_type() == "VOID") {
			show_error(SEMANTIC, VOID_USAGE, "", errorout);
			$$->set_data_type("ERROR");
		}
		else if ($1->get_data_type() == "ERROR" || $4->get_data_type() == "ERROR") {
			// show_error(SEMANTIC, TYPE_ERROR, "", errorout);
			$$->set_data_type("ERROR");
		}
		else if ($3->get_name() == "%") {
			if ($1->get_data_type() == "FLOAT" || $4->get_data_type() == "FLOAT") {
				show_error(SEMANTIC, MOD_OPERAND, "", errorout);
				$$->set_data_type("ERROR");
			}
			else if (is_zero($4->get_name())) {
				show_error(WARNING, MOD_BY_ZERO, "", errorout);
				$$->set_data_type("ERROR");
			}
			else {
				$$->set_data_type("INT");
			}
		}
		else if ($3->get_name() == "/") {
			if (is_zero($4->get_name())) {
				show_error(WARNING, DIV_BY_ZERO, "", errorout);
				$$->set_data_type("ERROR");
			}
			else {
				$$->set_data_type(type_cast($1->get_data_type(), $4->get_data_type()));
			}
		}
		else if ($3->get_name() == "*") {
			$$->set_data_type(type_cast($1->get_data_type(), $4->get_data_type()));
		}
		$$->set_rule("term : term MULOP unary_expression");
		$$->add_child($1); $$->add_child($3); $$->add_child($4);

		// icg code 
		generate_code("POP BX");
		generate_mulop_code($3->get_name());
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

		// icg code
		if ($1->get_name() == "-") {
			generate_code("NEG AX");
		}
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

		// icg code
		generate_logicop_code("NOT");
	}
	| factor {
		print_grammar_rule("unary_expression", "factor");
		$$ = new SymbolInfo($1->get_name(), "unary_expression", $1->get_data_type());
		$$->set_array($1->is_array());
		$$->set_rule("unary_expression : factor");
		$$->add_child($1);

		// icg code
		$$->set_truelist($1->get_truelist());
		$$->set_falselist($1->get_falselist());
		$$->set_nextlist($1->get_nextlist());
		$$->set_exp_evaluated($1->is_exp_evaluated());
	}
	;
	
factor : variable {
		print_grammar_rule("factor", "variable");
		$$ = new SymbolInfo($1->get_name(), "factor", $1->get_data_type());
		$$->set_array($1->is_array());
		$$->set_type($1->get_type());
		$$->set_rule("factor : variable");
		$$->add_child($1);

		// icg code
		if ($1->get_type() != "FROM_ARRAY") { // normal variable
			generate_code("MOV AX, " + get_variable_address($1));
		}
		else {
			if ($1->get_stack_offset() == -1) {
				// content of global array
				generate_code("LEA SI, " + $1->get_name());
				generate_code("SHL CX, 1");
				generate_code("ADD SI, CX");
				generate_code("MOV AX, [SI]");
			}
			else {
				generate_code("SHL CX, 1");
				generate_code("ADD CX, " + to_string($1->get_stack_offset()));
				generate_code("MOV DI, BP");
				generate_code("SUB DI, CX");
				generate_code("MOV AX, [DI]");
			}
		}
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

		// icg code
		$$->set_truelist($2->get_truelist());
		$$->set_falselist($2->get_falselist());
		$$->set_nextlist($2->get_nextlist());
		$$->set_exp_evaluated($2->is_exp_evaluated());

	}
	| CONST_INT {
		print_grammar_rule("factor", "CONST_INT");
		$$ = new SymbolInfo($1->get_name(), "factor", "INT");
		$$->set_rule("factor : CONST_INT");
		$$->add_child($1);

		// icg code
		generate_code("MOV AX, " + $1->get_name());
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

		// icg code
		generate_incop_code($1, "INC");
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

		// icg code
		generate_incop_code($1, "DEC");
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
		print_grammar_rule("argument_list", "");
		$$ = new SymbolInfo("", "argument_list");
		$$->set_rule("argument_list : ");
		$$->set_line(line_count, line_count);
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

LCURL_ : LCURL {
		$$ = $1;
		sym->enter_scope();
		sym->get_current_scope()->set_base_offset(current_offset);
		for (const Param& they : current_function_parameters) {
			if (they.name == "") { // nameless, no need to insert 
				show_error(SYNTAX, S_PARAM_NAMELESS, "", errorout);
				continue;
			}
			SymbolInfo* another = new SymbolInfo(they.name, "ID", they.data_type);
			another->set_array(they.is_array);
			if (!sym->insert(another)) {
				// insertion failed
				show_error(SEMANTIC, PARAM_REDEFINITION, another->get_name(), errorout);
				// in sample output, after any failure, the next arguments are not inserted to the symbol table, so breaking
				free_s(another);
				break;
			}
		}
		current_function_parameters.clear();
	}
	;

M : {
	$$ = new SymbolInfo();
	$$->set_label(newLabel());
	print_label($$->get_label());
}

N : {
	$$ = new SymbolInfo();
	generate_code("JMP");
	$$->add_to_nextlist(temp_file_lc - 1);
	cerr << "Generating a jump instruction at " << temp_file_lc - 1 << endl;
}

unary_boolean : {
	// icg code
	if (!(expression->is_exp_evaluated())) {
		// of the form if (i)
		generate_relop_code("jnz", expression);
	}
	expression->set_exp_evaluated(true);
}
 
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
	codeout.open("code.asm");
	tempout.open("temp.asm");

	sym = new SymbolTable(BUCKET_SIZE);

	yyin = fp;
	yyparse();

	fclose(yyin);
	delete sym;
	current_function_parameters.clear();

	logout << "Total Lines: " << line_count << "\n";
	logout << "Total Errors: " << error_count << "\n";
	treeout.close();
	errorout.close();
	logout.close();
	return 0;
}