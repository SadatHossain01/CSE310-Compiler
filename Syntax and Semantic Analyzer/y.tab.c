/* original parser id follows */
/* yysccsid[] = "@(#)yaccpar	1.9 (Berkeley) 02/21/93" */
/* (use YYMAJOR/YYMINOR for ifdefs dependent on parser version) */

#define YYBYACC 1
#define YYMAJOR 2
#define YYMINOR 0
#define YYPATCH 20220114

#define YYEMPTY        (-1)
#define yyclearin      (yychar = YYEMPTY)
#define yyerrok        (yyerrflag = 0)
#define YYRECOVERING() (yyerrflag != 0)
#define YYENOMEM       (-2)
#define YYEOF          0
#undef YYBTYACC
#define YYBTYACC 0
#define YYDEBUGSTR YYPREFIX "debug"
#define YYPREFIX "yy"

#define YYPURE 0

#line 2 "parser.y"
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
/* for some reason, for the func_declarations, after encountering the RPAREN, comp_statement's */
/* corresponding pointer is not being recognized and resulting in segmentation faults, but when*/
/* those same compound_statement pointers are kept in a global variable like the following, things*/
/* seem to work.*/
SymbolInfo* comp_statement; 

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
	current_function_parameters = param_list; /* no pointer used now, so should be no problem*/
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
		/* no parameter can be nameless in a function definition*/
		for (int i = 0; i < param_list.size(); i++) {
			if (param_list[i].name == "") {
				show_error(SEMANTIC, PARAM_NAMELESS, function->get_name(), errorout);
				free_s(function);
				return; /* returning as any such function is not acceptable*/
			}
		}
		/* just check the types of the parameters*/
		SymbolInfo* og_func = sym->search(function->get_name(), 'A');
		if (og_func == nullptr) {
			/* this is both declaration and definition then*/
			sym->insert(function);
		}
		else {
			if (!og_func->is_func_declaration() && !og_func->is_func_definition()) {
				/* same name variable already present with this name*/
				show_error(SEMANTIC, DIFFERENT_REDECLARATION, function->get_name(), errorout);
			}
			else if (og_func->is_func_definition()) {
				/* function definition already exists*/
				show_error(SEMANTIC, FUNC_REDEFINITION, function->get_name(), errorout);
			}
			/* already declaration exists*/
			else if (og_func->get_data_type() != type_specifier) {
				/* return type mismatch*/
				show_error(SEMANTIC, CONFLICTING_TYPE, function->get_name(), errorout);
			}
			else if (og_func->get_param_list().size() != param_list.size()) {
				/* parameter size mismatch*/
				show_error(SEMANTIC, CONFLICTING_TYPE, function->get_name(), errorout);
			}
			else {
				/* defintion param type and declaraion param type mismatch*/
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
		/* if it is a function definition, the check is done in lcurls -> LCURL, check there*/
		/* but if prototype, check not done there*/
		for (int i = 0; i < param_list.size(); i++) {
			for (int j = i + 1; j < param_list.size(); j++) {
				/* checking if any two parameters have same name except both being ""*/
				if (param_list[i].name == "") continue;
				if (param_list[i].name == param_list[j].name) {
					show_error(SEMANTIC, PARAM_REDEFINITION, param_list[i].name, errorout);
					free_s(function);
					return; /* returning as any such function is not acceptable*/
				}
			}
		}
		/* this is just a prototype*/
		SymbolInfo* og_func = sym->search(function->get_name(), 'A');
		if (og_func == nullptr) {
			/* this is both declaration and definition then*/
			sym->insert(function);
		}
		else {
			if (!og_func->is_func_declaration() && !og_func->is_func_definition()) {
				/* same name variable already present with this name*/
				show_error(SEMANTIC, DIFFERENT_REDECLARATION, function->get_name(), errorout);
			}
			else if (og_func->is_func_definition() || og_func->is_func_declaration()) {
				/* function definition already exists*/
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
	/* already guaranteed to be a valid number from lexer, so no need to check that again*/
	for (char c : str) {
		if (c != '0' && c != 'e' && c != 'E') return false;
	}
	return true;
}
#ifdef YYSTYPE
#undef  YYSTYPE_IS_DECLARED
#define YYSTYPE_IS_DECLARED 1
#endif
#ifndef YYSTYPE_IS_DECLARED
#define YYSTYPE_IS_DECLARED 1
#line 178 "parser.y"
typedef union YYSTYPE {
	SymbolInfo* symbol_info;
} YYSTYPE;
#endif /* !YYSTYPE_IS_DECLARED */
#line 205 "y.tab.c"

/* compatibility with bison */
#ifdef YYPARSE_PARAM
/* compatibility with FreeBSD */
# ifdef YYPARSE_PARAM_TYPE
#  define YYPARSE_DECL() yyparse(YYPARSE_PARAM_TYPE YYPARSE_PARAM)
# else
#  define YYPARSE_DECL() yyparse(void *YYPARSE_PARAM)
# endif
#else
# define YYPARSE_DECL() yyparse(void)
#endif

/* Parameters sent to lex. */
#ifdef YYLEX_PARAM
# define YYLEX_DECL() yylex(void *YYLEX_PARAM)
# define YYLEX yylex(YYLEX_PARAM)
#else
# define YYLEX_DECL() yylex(void)
# define YYLEX yylex()
#endif

#if !(defined(yylex) || defined(YYSTATE))
int YYLEX_DECL();
#endif

/* Parameters sent to yyerror. */
#ifndef YYERROR_DECL
#define YYERROR_DECL() yyerror(const char *s)
#endif
#ifndef YYERROR_CALL
#define YYERROR_CALL(msg) yyerror(msg)
#endif

extern int YYPARSE_DECL();

#define LOWER_THAN_ELSE 257
#define ELSE 258
#define IF 259
#define FOR 260
#define WHILE 261
#define DO 262
#define BREAK 263
#define RETURN 264
#define SWITCH 265
#define CASE 266
#define DEFAULT 267
#define CONTINUE 268
#define PRINTLN 269
#define ADDOP 270
#define INCOP 271
#define DECOP 272
#define RELOP 273
#define ASSIGNOP 274
#define LOGICOP 275
#define BITOP 276
#define NOT 277
#define LPAREN 278
#define RPAREN 279
#define LCURL 280
#define RCURL 281
#define LSQUARE 282
#define RSQUARE 283
#define COMMA 284
#define SEMICOLON 285
#define INT 286
#define CHAR 287
#define FLOAT 288
#define DOUBLE 289
#define VOID 290
#define CONST_INT 291
#define CONST_FLOAT 292
#define ID 293
#define MULOP 294
#define YYERRCODE 256
typedef int YYINT;
static const YYINT yylhs[] = {                           -1,
    0,    1,    1,    2,    2,    2,    2,    4,    4,    4,
   24,    5,   25,    5,   26,    5,    7,    7,    7,    7,
    8,    8,    8,    3,    3,    6,    6,    6,   10,   10,
   10,   10,    9,    9,   11,   11,   11,   11,   11,   11,
   11,   11,   11,   13,   13,   13,   20,   20,   12,   12,
   14,   14,   15,   15,   16,   16,   17,   17,   18,   18,
   18,   19,   19,   19,   19,   19,   19,   19,   21,   21,
   21,   22,   22,   23,
};
static const YYINT yylen[] = {                            2,
    1,    2,    1,    1,    1,    1,    1,    6,    6,    5,
    0,    7,    0,    7,    0,    6,    4,    3,    2,    1,
    3,    3,    2,    3,    3,    1,    1,    1,    3,    6,
    1,    4,    1,    2,    1,    1,    1,    7,    5,    7,
    5,    5,    3,    1,    2,    2,    1,    4,    1,    3,
    1,    3,    1,    3,    1,    3,    1,    3,    2,    2,
    1,    1,    4,    3,    1,    1,    2,    2,    1,    2,
    0,    3,    1,    1,
};
static const YYINT yydefred[] = {                         0,
    7,   26,   27,   28,    0,    0,    3,    4,    5,    6,
    0,    2,    0,    0,    0,   25,    0,    0,    0,   24,
    0,    0,    0,    0,    0,    0,    0,   10,    0,   19,
    0,    0,   32,    0,    9,    0,   74,   16,    0,    8,
    0,    0,    0,   14,    0,    0,    0,    0,    0,    0,
    0,    0,    0,   23,   44,   65,   66,    0,   35,    0,
   37,    0,   33,    0,   36,   49,    0,    0,    0,   57,
   61,    0,   12,   17,   30,   22,   46,    0,    0,    0,
    0,    0,   59,    0,   60,    0,    0,    0,    0,    0,
   21,   34,   45,    0,    0,    0,    0,   67,   68,    0,
    0,    0,    0,   43,    0,   64,   73,    0,    0,    0,
   52,    0,    0,   58,   50,    0,    0,    0,    0,   63,
   70,    0,   48,    0,    0,   41,   42,   72,    0,    0,
   40,   38,
};
#if defined(YYDESTRUCT_CALL) || defined(YYSTYPE_TOSTRING)
static const YYINT yystos[] = {                           0,
  256,  286,  288,  290,  296,  297,  298,  299,  300,  301,
  302,  298,  256,  293,  306,  285,  278,  282,  284,  285,
  256,  279,  302,  303,  291,  293,  279,  285,  322,  293,
  279,  284,  283,  282,  285,  321,  280,  304,  319,  285,
  320,  302,  291,  304,  256,  259,  260,  261,  264,  269,
  270,  277,  278,  281,  285,  291,  292,  293,  299,  302,
  304,  305,  307,  308,  309,  310,  311,  312,  313,  314,
  315,  316,  304,  293,  283,  281,  285,  278,  278,  278,
  308,  278,  314,  316,  314,  308,  278,  282,  293,  256,
  281,  307,  285,  275,  270,  273,  294,  271,  272,  274,
  308,  309,  308,  285,  293,  279,  310,  317,  318,  308,
  311,  313,  312,  314,  310,  279,  309,  279,  279,  279,
  256,  284,  283,  307,  308,  307,  285,  310,  258,  279,
  307,  307,
};
#endif /* YYDESTRUCT_CALL || YYSTYPE_TOSTRING */
static const YYINT yydgoto[] = {                          5,
    6,    7,   59,    9,   10,   60,   24,   61,   62,   15,
   63,   64,   65,   66,   67,   68,   69,   70,   71,   72,
  108,  109,   39,   41,   36,   29,
};
static const YYINT yysindex[] = {                      -234,
    0,    0,    0,    0,    0, -234,    0,    0,    0,    0,
 -246,    0, -272, -262, -193,    0, -222, -209, -264,    0,
 -237, -216, -200, -249, -186, -181, -175,    0, -165,    0,
 -166, -172,    0, -169,    0, -165,    0,    0, -157,    0,
 -165, -150, -153,    0, -230, -129, -123, -122,    9, -121,
    9,    9,    9,    0,    0,    0,    0, -259,    0, -245,
    0, -119,    0, -125,    0,    0, -111, -208, -126,    0,
    0, -163,    0,    0,    0,    0,    0,    9, -253,    9,
 -120, -117,    0, -145,    0, -109,    9,    9, -105, -104,
    0,    0,    0,    9,    9,    9,    9,    0,    0,    9,
  -95, -253,  -94,    0,  -92,    0,    0,  -86, -247,  -89,
    0, -126,  -68,    0,    0,  -43,    9,  -43,  -90,    0,
    0,    9,    0,  -60,  -76,    0,    0,    0,  -43,  -43,
    0,    0,
};
static const YYINT yyrindex[] = {                         0,
    0,    0,    0,    0,    0,  206,    0,    0,    0,    0,
    0,    0,    0, -146,    0,    0,    0,    0,    0,    0,
    0,  -66, -221,    0,    0, -138,  -65,    0,    0,    0,
  -61,    0,    0,    0,    0,    0,    0,    0,    0,    0,
    0, -199,    0,    0,    0,    0,    0,    0,    0,    0,
    0,    0,    0,    0,    0,    0,    0, -196,    0,    0,
    0,    0,    0,    0,    0,    0,  -55, -131,  -18,    0,
    0,    5,    0,    0,    0,    0,    0,    0,    0,    0,
    0,    0,    0, -189,    0,    0,  -71,    0, -146,    0,
    0,    0,    0,    0,    0,    0,    0,    0,    0,    0,
    0,    0,    0,    0,    0,    0,    0,    0,  -59,    0,
    0,   -2,  -93,    0,    0,    0,    0,    0,    0,    0,
    0,    0,    0,  -81,    0,    0,    0,    0,    0,    0,
    0,    0,
};
#if YYBTYACC
static const YYINT yycindex[] = {                         0,
    0,    0,    0,    0,    0,    0,    0,    0,    0,    0,
    0,    0,    0,    0,    0,    0,    0,    0,    0,    0,
    0,    0,    0,    0,    0,    0,    0,    0,    0,    0,
    0,    0,    0,    0,    0,    0,    0,    0,    0,    0,
    0,    0,    0,    0,    0,    0,    0,    0,    0,    0,
    0,    0,    0,    0,    0,    0,    0,    0,    0,    0,
    0,    0,    0,    0,    0,    0,    0,    0,    0,    0,
    0,    0,    0,    0,    0,    0,    0,    0,    0,    0,
    0,    0,    0,    0,    0,    0,    0,    0,    0,    0,
    0,    0,    0,    0,    0,    0,    0,    0,    0,    0,
    0,    0,    0,    0,    0,    0,    0,    0,    0,    0,
    0,    0,    0,    0,    0,    0,    0,    0,    0,    0,
    0,    0,    0,    0,    0,    0,    0,    0,    0,    0,
    0,    0,
};
#endif
static const YYINT yygindex[] = {                         0,
    0,  216,   12,    0,    0,  100,    0,  -15,    0,    0,
  -57,  -47,  -75,  -72,  129,  135,  130,  -44,    0,  -51,
    0,    0,    0,    0,    0,    0,
};
#define YYTABLESIZE 302
static const YYINT yytable[] = {                         84,
   84,   81,   90,  102,   92,   86,   83,   85,  121,   13,
   13,    8,   16,   38,  107,   17,   51,    8,   87,   18,
   44,    1,   88,   52,   53,   73,  117,  115,   26,   31,
  101,   55,  103,   21,   32,   84,  122,   56,   57,   58,
  110,   27,   84,   84,   84,   84,   14,   89,   84,  128,
   76,    2,  114,    3,   77,    4,   22,   20,  124,   47,
  126,   95,   20,    2,   96,    3,   62,    4,   28,  125,
   84,  131,  132,   47,   47,   47,   47,   47,   47,   18,
   62,   25,   47,   62,   18,   62,   47,   47,   47,   62,
   19,   20,   30,   62,   62,   62,   33,   47,   45,   11,
   34,   46,   47,   48,   62,   11,   49,   98,   99,   35,
  100,   50,   51,    2,   37,    3,   23,    4,   40,   52,
   53,   43,   37,   54,   53,   98,   99,   55,    2,   75,
    3,   42,    4,   56,   57,   58,   90,   31,   31,   46,
   47,   48,   74,   53,   49,   29,   29,   53,   78,   50,
   51,   53,   53,   53,   79,   80,   82,   52,   53,   93,
   37,   91,   54,   94,  104,   55,    2,   97,    3,  106,
    4,   56,   57,   58,   39,  105,   18,   39,   39,   39,
   77,   54,   39,  116,  118,   54,  119,   39,   39,   54,
   54,   54,  120,  123,  127,   39,   39,  129,   39,   39,
   51,   95,  130,   39,   39,    1,   39,   71,   39,   39,
   39,   39,   90,   15,   13,   46,   47,   48,   11,   69,
   49,   12,  111,   51,  112,   50,   51,   51,   51,   51,
  113,    0,    0,   52,   53,    0,   37,   55,    0,    0,
    0,   55,    2,    0,    3,    0,    4,   56,   57,   58,
    0,   55,    0,   56,   55,    0,   55,    0,    0,    0,
   55,    0,    0,    0,   55,   55,   55,   56,    0,    0,
   56,    0,   56,    0,   62,    0,   56,   62,   51,   62,
   56,   56,   56,   62,    0,   52,   53,   62,    0,   62,
    0,    0,    0,    0,    0,    0,    0,    0,   62,   56,
   57,   58,
};
static const YYINT yycheck[] = {                         51,
   52,   49,  256,   79,   62,   53,   51,   52,  256,  256,
  256,    0,  285,   29,   87,  278,  270,    6,  278,  282,
   36,  256,  282,  277,  278,   41,  102,  100,  293,  279,
   78,  285,   80,  256,  284,   87,  284,  291,  292,  293,
   88,  279,   94,   95,   96,   97,  293,  293,  100,  122,
  281,  286,   97,  288,  285,  290,  279,  279,  116,  256,
  118,  270,  284,  286,  273,  288,  256,  290,  285,  117,
  122,  129,  130,  270,  271,  272,  273,  274,  275,  279,
  270,  291,  279,  273,  284,  275,  283,  284,  285,  279,
  284,  285,  293,  283,  284,  285,  283,  294,  256,    0,
  282,  259,  260,  261,  294,    6,  264,  271,  272,  285,
  274,  269,  270,  286,  280,  288,   17,  290,  285,  277,
  278,  291,  280,  281,  256,  271,  272,  285,  286,  283,
  288,   32,  290,  291,  292,  293,  256,  284,  285,  259,
  260,  261,  293,  275,  264,  284,  285,  279,  278,  269,
  270,  283,  284,  285,  278,  278,  278,  277,  278,  285,
  280,  281,  256,  275,  285,  285,  286,  294,  288,  279,
  290,  291,  292,  293,  256,  293,  282,  259,  260,  261,
  285,  275,  264,  279,  279,  279,  279,  269,  270,  283,
  284,  285,  279,  283,  285,  277,  278,  258,  280,  281,
  256,  270,  279,  285,  286,    0,  288,  279,  290,  291,
  292,  293,  256,  280,  280,  259,  260,  261,  280,  279,
  264,    6,   94,  279,   95,  269,  270,  283,  284,  285,
   96,   -1,   -1,  277,  278,   -1,  280,  256,   -1,   -1,
   -1,  285,  286,   -1,  288,   -1,  290,  291,  292,  293,
   -1,  270,   -1,  256,  273,   -1,  275,   -1,   -1,   -1,
  279,   -1,   -1,   -1,  283,  284,  285,  270,   -1,   -1,
  273,   -1,  275,   -1,  270,   -1,  279,  273,  270,  275,
  283,  284,  285,  279,   -1,  277,  278,  283,   -1,  285,
   -1,   -1,   -1,   -1,   -1,   -1,   -1,   -1,  294,  291,
  292,  293,
};
#if YYBTYACC
static const YYINT yyctable[] = {                        -1,
   -1,   -1,   -1,   -1,   -1,   -1,   -1,   -1,   -1,   -1,
   -1,   -1,   -1,   -1,   -1,   -1,   -1,   -1,   -1,   -1,
   -1,   -1,   -1,   -1,   -1,   -1,   -1,   -1,   -1,   -1,
   -1,   -1,   -1,   -1,   -1,   -1,   -1,   -1,   -1,   -1,
   -1,   -1,   -1,   -1,   -1,   -1,   -1,   -1,   -1,   -1,
   -1,   -1,   -1,   -1,   -1,   -1,   -1,   -1,   -1,   -1,
   -1,   -1,   -1,   -1,   -1,   -1,   -1,   -1,   -1,   -1,
   -1,   -1,   -1,   -1,   -1,   -1,   -1,   -1,   -1,   -1,
   -1,   -1,   -1,   -1,   -1,   -1,   -1,   -1,   -1,   -1,
   -1,   -1,   -1,   -1,   -1,   -1,   -1,   -1,   -1,   -1,
   -1,   -1,   -1,   -1,   -1,   -1,   -1,   -1,   -1,   -1,
   -1,   -1,   -1,   -1,   -1,   -1,   -1,   -1,   -1,   -1,
   -1,   -1,   -1,   -1,   -1,   -1,   -1,   -1,   -1,   -1,
   -1,   -1,   -1,   -1,   -1,   -1,   -1,   -1,   -1,   -1,
   -1,   -1,   -1,   -1,   -1,   -1,   -1,   -1,   -1,   -1,
   -1,   -1,   -1,   -1,   -1,   -1,   -1,   -1,   -1,   -1,
   -1,   -1,   -1,   -1,   -1,   -1,   -1,   -1,   -1,   -1,
   -1,   -1,   -1,   -1,   -1,   -1,   -1,   -1,   -1,   -1,
   -1,   -1,   -1,   -1,   -1,   -1,   -1,   -1,   -1,   -1,
   -1,   -1,   -1,   -1,   -1,   -1,   -1,   -1,   -1,   -1,
   -1,   -1,   -1,   -1,   -1,   -1,   -1,   -1,   -1,   -1,
   -1,   -1,   -1,   -1,   -1,   -1,   -1,   -1,   -1,   -1,
   -1,   -1,   -1,   -1,   -1,   -1,   -1,   -1,   -1,   -1,
   -1,   -1,   -1,   -1,   -1,   -1,   -1,   -1,   -1,   -1,
   -1,   -1,   -1,   -1,   -1,   -1,   -1,   -1,   -1,   -1,
   -1,   -1,   -1,   -1,   -1,   -1,   -1,   -1,   -1,   -1,
   -1,   -1,   -1,   -1,   -1,   -1,   -1,   -1,   -1,   -1,
   -1,   -1,   -1,   -1,   -1,   -1,   -1,   -1,   -1,   -1,
   -1,   -1,   -1,   -1,   -1,   -1,   -1,   -1,   -1,   -1,
   -1,   -1,   -1,   -1,   -1,   -1,   -1,   -1,   -1,   -1,
   -1,
};
#endif
#define YYFINAL 5
#ifndef YYDEBUG
#define YYDEBUG 0
#endif
#define YYMAXTOKEN 294
#define YYUNDFTOKEN 323
#define YYTRANSLATE(a) ((a) > YYMAXTOKEN ? YYUNDFTOKEN : (a))
#if YYDEBUG
static const char *const yyname[] = {

"$end",0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,
0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,
0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,
0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,
0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,
0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,
0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,"error","LOWER_THAN_ELSE","ELSE","IF",
"FOR","WHILE","DO","BREAK","RETURN","SWITCH","CASE","DEFAULT","CONTINUE",
"PRINTLN","ADDOP","INCOP","DECOP","RELOP","ASSIGNOP","LOGICOP","BITOP","NOT",
"LPAREN","RPAREN","LCURL","RCURL","LSQUARE","RSQUARE","COMMA","SEMICOLON","INT",
"CHAR","FLOAT","DOUBLE","VOID","CONST_INT","CONST_FLOAT","ID","MULOP","$accept",
"start","program","unit","var_declaration","func_declaration","func_definition",
"type_specifier","parameter_list","compound_statement","statements",
"declaration_list","statement","expression","expression_statement",
"logic_expression","rel_expression","simple_expression","term",
"unary_expression","factor","variable","argument_list","arguments","lcurls",
"$$1","$$2","$$3","illegal-symbol",
};
static const char *const yyrule[] = {
"$accept : start",
"start : program",
"program : program unit",
"program : unit",
"unit : var_declaration",
"unit : func_declaration",
"unit : func_definition",
"unit : error",
"func_declaration : type_specifier ID LPAREN parameter_list RPAREN SEMICOLON",
"func_declaration : type_specifier ID LPAREN error RPAREN SEMICOLON",
"func_declaration : type_specifier ID LPAREN RPAREN SEMICOLON",
"$$1 :",
"func_definition : type_specifier ID LPAREN parameter_list RPAREN $$1 compound_statement",
"$$2 :",
"func_definition : type_specifier ID LPAREN error RPAREN $$2 compound_statement",
"$$3 :",
"func_definition : type_specifier ID LPAREN RPAREN $$3 compound_statement",
"parameter_list : parameter_list COMMA type_specifier ID",
"parameter_list : parameter_list COMMA type_specifier",
"parameter_list : type_specifier ID",
"parameter_list : type_specifier",
"compound_statement : lcurls statements RCURL",
"compound_statement : lcurls error RCURL",
"compound_statement : lcurls RCURL",
"var_declaration : type_specifier declaration_list SEMICOLON",
"var_declaration : type_specifier error SEMICOLON",
"type_specifier : INT",
"type_specifier : FLOAT",
"type_specifier : VOID",
"declaration_list : declaration_list COMMA ID",
"declaration_list : declaration_list COMMA ID LSQUARE CONST_INT RSQUARE",
"declaration_list : ID",
"declaration_list : ID LSQUARE CONST_INT RSQUARE",
"statements : statement",
"statements : statements statement",
"statement : var_declaration",
"statement : expression_statement",
"statement : compound_statement",
"statement : FOR LPAREN expression_statement expression_statement expression RPAREN statement",
"statement : IF LPAREN expression RPAREN statement",
"statement : IF LPAREN expression RPAREN statement ELSE statement",
"statement : WHILE LPAREN expression RPAREN statement",
"statement : PRINTLN LPAREN ID RPAREN SEMICOLON",
"statement : RETURN expression SEMICOLON",
"expression_statement : SEMICOLON",
"expression_statement : expression SEMICOLON",
"expression_statement : error SEMICOLON",
"variable : ID",
"variable : ID LSQUARE expression RSQUARE",
"expression : logic_expression",
"expression : variable ASSIGNOP logic_expression",
"logic_expression : rel_expression",
"logic_expression : rel_expression LOGICOP rel_expression",
"rel_expression : simple_expression",
"rel_expression : simple_expression RELOP simple_expression",
"simple_expression : term",
"simple_expression : simple_expression ADDOP term",
"term : unary_expression",
"term : term MULOP unary_expression",
"unary_expression : ADDOP unary_expression",
"unary_expression : NOT unary_expression",
"unary_expression : factor",
"factor : variable",
"factor : ID LPAREN argument_list RPAREN",
"factor : LPAREN expression RPAREN",
"factor : CONST_INT",
"factor : CONST_FLOAT",
"factor : variable INCOP",
"factor : variable DECOP",
"argument_list : arguments",
"argument_list : arguments error",
"argument_list :",
"arguments : arguments COMMA logic_expression",
"arguments : logic_expression",
"lcurls : LCURL",

};
#endif

#if YYDEBUG
int      yydebug;
#endif

int      yyerrflag;
int      yychar;
YYSTYPE  yyval;
YYSTYPE  yylval;
int      yynerrs;

#if defined(YYLTYPE) || defined(YYLTYPE_IS_DECLARED)
YYLTYPE  yyloc; /* position returned by actions */
YYLTYPE  yylloc; /* position from the lexer */
#endif

#if defined(YYLTYPE) || defined(YYLTYPE_IS_DECLARED)
#ifndef YYLLOC_DEFAULT
#define YYLLOC_DEFAULT(loc, rhs, n) \
do \
{ \
    if (n == 0) \
    { \
        (loc).first_line   = YYRHSLOC(rhs, 0).last_line; \
        (loc).first_column = YYRHSLOC(rhs, 0).last_column; \
        (loc).last_line    = YYRHSLOC(rhs, 0).last_line; \
        (loc).last_column  = YYRHSLOC(rhs, 0).last_column; \
    } \
    else \
    { \
        (loc).first_line   = YYRHSLOC(rhs, 1).first_line; \
        (loc).first_column = YYRHSLOC(rhs, 1).first_column; \
        (loc).last_line    = YYRHSLOC(rhs, n).last_line; \
        (loc).last_column  = YYRHSLOC(rhs, n).last_column; \
    } \
} while (0)
#endif /* YYLLOC_DEFAULT */
#endif /* defined(YYLTYPE) || defined(YYLTYPE_IS_DECLARED) */
#if YYBTYACC

#ifndef YYLVQUEUEGROWTH
#define YYLVQUEUEGROWTH 32
#endif
#endif /* YYBTYACC */

/* define the initial stack-sizes */
#ifdef YYSTACKSIZE
#undef YYMAXDEPTH
#define YYMAXDEPTH  YYSTACKSIZE
#else
#ifdef YYMAXDEPTH
#define YYSTACKSIZE YYMAXDEPTH
#else
#define YYSTACKSIZE 10000
#define YYMAXDEPTH  10000
#endif
#endif

#ifndef YYINITSTACKSIZE
#define YYINITSTACKSIZE 200
#endif

typedef struct {
    unsigned stacksize;
    YYINT    *s_base;
    YYINT    *s_mark;
    YYINT    *s_last;
    YYSTYPE  *l_base;
    YYSTYPE  *l_mark;
#if defined(YYLTYPE) || defined(YYLTYPE_IS_DECLARED)
    YYLTYPE  *p_base;
    YYLTYPE  *p_mark;
#endif
} YYSTACKDATA;
#if YYBTYACC

struct YYParseState_s
{
    struct YYParseState_s *save;    /* Previously saved parser state */
    YYSTACKDATA            yystack; /* saved parser stack */
    int                    state;   /* saved parser state */
    int                    errflag; /* saved error recovery status */
    int                    lexeme;  /* saved index of the conflict lexeme in the lexical queue */
    YYINT                  ctry;    /* saved index in yyctable[] for this conflict */
};
typedef struct YYParseState_s YYParseState;
#endif /* YYBTYACC */
/* variables for the parser stack */
static YYSTACKDATA yystack;
#if YYBTYACC

/* Current parser state */
static YYParseState *yyps = 0;

/* yypath != NULL: do the full parse, starting at *yypath parser state. */
static YYParseState *yypath = 0;

/* Base of the lexical value queue */
static YYSTYPE *yylvals = 0;

/* Current position at lexical value queue */
static YYSTYPE *yylvp = 0;

/* End position of lexical value queue */
static YYSTYPE *yylve = 0;

/* The last allocated position at the lexical value queue */
static YYSTYPE *yylvlim = 0;

#if defined(YYLTYPE) || defined(YYLTYPE_IS_DECLARED)
/* Base of the lexical position queue */
static YYLTYPE *yylpsns = 0;

/* Current position at lexical position queue */
static YYLTYPE *yylpp = 0;

/* End position of lexical position queue */
static YYLTYPE *yylpe = 0;

/* The last allocated position at the lexical position queue */
static YYLTYPE *yylplim = 0;
#endif

/* Current position at lexical token queue */
static YYINT  *yylexp = 0;

static YYINT  *yylexemes = 0;
#endif /* YYBTYACC */
#line 949 "parser.y"

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

#line 767 "y.tab.c"

/* For use in generated program */
#define yydepth (int)(yystack.s_mark - yystack.s_base)
#if YYBTYACC
#define yytrial (yyps->save)
#endif /* YYBTYACC */

#if YYDEBUG
#include <stdio.h>	/* needed for printf */
#endif

#include <stdlib.h>	/* needed for malloc, etc */
#include <string.h>	/* needed for memset */

/* allocate initial stack or double stack size, up to YYMAXDEPTH */
static int yygrowstack(YYSTACKDATA *data)
{
    int i;
    unsigned newsize;
    YYINT *newss;
    YYSTYPE *newvs;
#if defined(YYLTYPE) || defined(YYLTYPE_IS_DECLARED)
    YYLTYPE *newps;
#endif

    if ((newsize = data->stacksize) == 0)
        newsize = YYINITSTACKSIZE;
    else if (newsize >= YYMAXDEPTH)
        return YYENOMEM;
    else if ((newsize *= 2) > YYMAXDEPTH)
        newsize = YYMAXDEPTH;

    i = (int) (data->s_mark - data->s_base);
    newss = (YYINT *)realloc(data->s_base, newsize * sizeof(*newss));
    if (newss == 0)
        return YYENOMEM;

    data->s_base = newss;
    data->s_mark = newss + i;

    newvs = (YYSTYPE *)realloc(data->l_base, newsize * sizeof(*newvs));
    if (newvs == 0)
        return YYENOMEM;

    data->l_base = newvs;
    data->l_mark = newvs + i;

#if defined(YYLTYPE) || defined(YYLTYPE_IS_DECLARED)
    newps = (YYLTYPE *)realloc(data->p_base, newsize * sizeof(*newps));
    if (newps == 0)
        return YYENOMEM;

    data->p_base = newps;
    data->p_mark = newps + i;
#endif

    data->stacksize = newsize;
    data->s_last = data->s_base + newsize - 1;

#if YYDEBUG
    if (yydebug)
        fprintf(stderr, "%sdebug: stack size increased to %d\n", YYPREFIX, newsize);
#endif
    return 0;
}

#if YYPURE || defined(YY_NO_LEAKS)
static void yyfreestack(YYSTACKDATA *data)
{
    free(data->s_base);
    free(data->l_base);
#if defined(YYLTYPE) || defined(YYLTYPE_IS_DECLARED)
    free(data->p_base);
#endif
    memset(data, 0, sizeof(*data));
}
#else
#define yyfreestack(data) /* nothing */
#endif /* YYPURE || defined(YY_NO_LEAKS) */
#if YYBTYACC

static YYParseState *
yyNewState(unsigned size)
{
    YYParseState *p = (YYParseState *) malloc(sizeof(YYParseState));
    if (p == NULL) return NULL;

    p->yystack.stacksize = size;
    if (size == 0)
    {
        p->yystack.s_base = NULL;
        p->yystack.l_base = NULL;
#if defined(YYLTYPE) || defined(YYLTYPE_IS_DECLARED)
        p->yystack.p_base = NULL;
#endif
        return p;
    }
    p->yystack.s_base    = (YYINT *) malloc(size * sizeof(YYINT));
    if (p->yystack.s_base == NULL) return NULL;
    p->yystack.l_base    = (YYSTYPE *) malloc(size * sizeof(YYSTYPE));
    if (p->yystack.l_base == NULL) return NULL;
    memset(p->yystack.l_base, 0, size * sizeof(YYSTYPE));
#if defined(YYLTYPE) || defined(YYLTYPE_IS_DECLARED)
    p->yystack.p_base    = (YYLTYPE *) malloc(size * sizeof(YYLTYPE));
    if (p->yystack.p_base == NULL) return NULL;
    memset(p->yystack.p_base, 0, size * sizeof(YYLTYPE));
#endif

    return p;
}

static void
yyFreeState(YYParseState *p)
{
    yyfreestack(&p->yystack);
    free(p);
}
#endif /* YYBTYACC */

#define YYABORT  goto yyabort
#define YYREJECT goto yyabort
#define YYACCEPT goto yyaccept
#define YYERROR  goto yyerrlab
#if YYBTYACC
#define YYVALID        do { if (yyps->save)            goto yyvalid; } while(0)
#define YYVALID_NESTED do { if (yyps->save && \
                                yyps->save->save == 0) goto yyvalid; } while(0)
#endif /* YYBTYACC */

int
YYPARSE_DECL()
{
    int yym, yyn, yystate, yyresult;
#if YYBTYACC
    int yynewerrflag;
    YYParseState *yyerrctx = NULL;
#endif /* YYBTYACC */
#if defined(YYLTYPE) || defined(YYLTYPE_IS_DECLARED)
    YYLTYPE  yyerror_loc_range[3]; /* position of error start/end (0 unused) */
#endif
#if YYDEBUG
    const char *yys;

    if ((yys = getenv("YYDEBUG")) != 0)
    {
        yyn = *yys;
        if (yyn >= '0' && yyn <= '9')
            yydebug = yyn - '0';
    }
    if (yydebug)
        fprintf(stderr, "%sdebug[<# of symbols on state stack>]\n", YYPREFIX);
#endif
#if defined(YYLTYPE) || defined(YYLTYPE_IS_DECLARED)
    memset(yyerror_loc_range, 0, sizeof(yyerror_loc_range));
#endif

#if YYBTYACC
    yyps = yyNewState(0); if (yyps == 0) goto yyenomem;
    yyps->save = 0;
#endif /* YYBTYACC */
    yym = 0;
    /* yyn is set below */
    yynerrs = 0;
    yyerrflag = 0;
    yychar = YYEMPTY;
    yystate = 0;

#if YYPURE
    memset(&yystack, 0, sizeof(yystack));
#endif

    if (yystack.s_base == NULL && yygrowstack(&yystack) == YYENOMEM) goto yyoverflow;
    yystack.s_mark = yystack.s_base;
    yystack.l_mark = yystack.l_base;
#if defined(YYLTYPE) || defined(YYLTYPE_IS_DECLARED)
    yystack.p_mark = yystack.p_base;
#endif
    yystate = 0;
    *yystack.s_mark = 0;

yyloop:
    if ((yyn = yydefred[yystate]) != 0) goto yyreduce;
    if (yychar < 0)
    {
#if YYBTYACC
        do {
        if (yylvp < yylve)
        {
            /* we're currently re-reading tokens */
            yylval = *yylvp++;
#if defined(YYLTYPE) || defined(YYLTYPE_IS_DECLARED)
            yylloc = *yylpp++;
#endif
            yychar = *yylexp++;
            break;
        }
        if (yyps->save)
        {
            /* in trial mode; save scanner results for future parse attempts */
            if (yylvp == yylvlim)
            {   /* Enlarge lexical value queue */
                size_t p = (size_t) (yylvp - yylvals);
                size_t s = (size_t) (yylvlim - yylvals);

                s += YYLVQUEUEGROWTH;
                if ((yylexemes = (YYINT *)realloc(yylexemes, s * sizeof(YYINT))) == NULL) goto yyenomem;
                if ((yylvals   = (YYSTYPE *)realloc(yylvals, s * sizeof(YYSTYPE))) == NULL) goto yyenomem;
#if defined(YYLTYPE) || defined(YYLTYPE_IS_DECLARED)
                if ((yylpsns   = (YYLTYPE *)realloc(yylpsns, s * sizeof(YYLTYPE))) == NULL) goto yyenomem;
#endif
                yylvp   = yylve = yylvals + p;
                yylvlim = yylvals + s;
#if defined(YYLTYPE) || defined(YYLTYPE_IS_DECLARED)
                yylpp   = yylpe = yylpsns + p;
                yylplim = yylpsns + s;
#endif
                yylexp  = yylexemes + p;
            }
            *yylexp = (YYINT) YYLEX;
            *yylvp++ = yylval;
            yylve++;
#if defined(YYLTYPE) || defined(YYLTYPE_IS_DECLARED)
            *yylpp++ = yylloc;
            yylpe++;
#endif
            yychar = *yylexp++;
            break;
        }
        /* normal operation, no conflict encountered */
#endif /* YYBTYACC */
        yychar = YYLEX;
#if YYBTYACC
        } while (0);
#endif /* YYBTYACC */
        if (yychar < 0) yychar = YYEOF;
#if YYDEBUG
        if (yydebug)
        {
            if ((yys = yyname[YYTRANSLATE(yychar)]) == NULL) yys = yyname[YYUNDFTOKEN];
            fprintf(stderr, "%s[%d]: state %d, reading token %d (%s)",
                            YYDEBUGSTR, yydepth, yystate, yychar, yys);
#ifdef YYSTYPE_TOSTRING
#if YYBTYACC
            if (!yytrial)
#endif /* YYBTYACC */
                fprintf(stderr, " <%s>", YYSTYPE_TOSTRING(yychar, yylval));
#endif
            fputc('\n', stderr);
        }
#endif
    }
#if YYBTYACC

    /* Do we have a conflict? */
    if (((yyn = yycindex[yystate]) != 0) && (yyn += yychar) >= 0 &&
        yyn <= YYTABLESIZE && yycheck[yyn] == (YYINT) yychar)
    {
        YYINT ctry;

        if (yypath)
        {
            YYParseState *save;
#if YYDEBUG
            if (yydebug)
                fprintf(stderr, "%s[%d]: CONFLICT in state %d: following successful trial parse\n",
                                YYDEBUGSTR, yydepth, yystate);
#endif
            /* Switch to the next conflict context */
            save = yypath;
            yypath = save->save;
            save->save = NULL;
            ctry = save->ctry;
            if (save->state != yystate) YYABORT;
            yyFreeState(save);

        }
        else
        {

            /* Unresolved conflict - start/continue trial parse */
            YYParseState *save;
#if YYDEBUG
            if (yydebug)
            {
                fprintf(stderr, "%s[%d]: CONFLICT in state %d. ", YYDEBUGSTR, yydepth, yystate);
                if (yyps->save)
                    fputs("ALREADY in conflict, continuing trial parse.\n", stderr);
                else
                    fputs("Starting trial parse.\n", stderr);
            }
#endif
            save                  = yyNewState((unsigned)(yystack.s_mark - yystack.s_base + 1));
            if (save == NULL) goto yyenomem;
            save->save            = yyps->save;
            save->state           = yystate;
            save->errflag         = yyerrflag;
            save->yystack.s_mark  = save->yystack.s_base + (yystack.s_mark - yystack.s_base);
            memcpy (save->yystack.s_base, yystack.s_base, (size_t) (yystack.s_mark - yystack.s_base + 1) * sizeof(YYINT));
            save->yystack.l_mark  = save->yystack.l_base + (yystack.l_mark - yystack.l_base);
            memcpy (save->yystack.l_base, yystack.l_base, (size_t) (yystack.l_mark - yystack.l_base + 1) * sizeof(YYSTYPE));
#if defined(YYLTYPE) || defined(YYLTYPE_IS_DECLARED)
            save->yystack.p_mark  = save->yystack.p_base + (yystack.p_mark - yystack.p_base);
            memcpy (save->yystack.p_base, yystack.p_base, (size_t) (yystack.p_mark - yystack.p_base + 1) * sizeof(YYLTYPE));
#endif
            ctry                  = yytable[yyn];
            if (yyctable[ctry] == -1)
            {
#if YYDEBUG
                if (yydebug && yychar >= YYEOF)
                    fprintf(stderr, "%s[%d]: backtracking 1 token\n", YYDEBUGSTR, yydepth);
#endif
                ctry++;
            }
            save->ctry = ctry;
            if (yyps->save == NULL)
            {
                /* If this is a first conflict in the stack, start saving lexemes */
                if (!yylexemes)
                {
                    yylexemes = (YYINT *) malloc((YYLVQUEUEGROWTH) * sizeof(YYINT));
                    if (yylexemes == NULL) goto yyenomem;
                    yylvals   = (YYSTYPE *) malloc((YYLVQUEUEGROWTH) * sizeof(YYSTYPE));
                    if (yylvals == NULL) goto yyenomem;
                    yylvlim   = yylvals + YYLVQUEUEGROWTH;
#if defined(YYLTYPE) || defined(YYLTYPE_IS_DECLARED)
                    yylpsns   = (YYLTYPE *) malloc((YYLVQUEUEGROWTH) * sizeof(YYLTYPE));
                    if (yylpsns == NULL) goto yyenomem;
                    yylplim   = yylpsns + YYLVQUEUEGROWTH;
#endif
                }
                if (yylvp == yylve)
                {
                    yylvp  = yylve = yylvals;
#if defined(YYLTYPE) || defined(YYLTYPE_IS_DECLARED)
                    yylpp  = yylpe = yylpsns;
#endif
                    yylexp = yylexemes;
                    if (yychar >= YYEOF)
                    {
                        *yylve++ = yylval;
#if defined(YYLTYPE) || defined(YYLTYPE_IS_DECLARED)
                        *yylpe++ = yylloc;
#endif
                        *yylexp  = (YYINT) yychar;
                        yychar   = YYEMPTY;
                    }
                }
            }
            if (yychar >= YYEOF)
            {
                yylvp--;
#if defined(YYLTYPE) || defined(YYLTYPE_IS_DECLARED)
                yylpp--;
#endif
                yylexp--;
                yychar = YYEMPTY;
            }
            save->lexeme = (int) (yylvp - yylvals);
            yyps->save   = save;
        }
        if (yytable[yyn] == ctry)
        {
#if YYDEBUG
            if (yydebug)
                fprintf(stderr, "%s[%d]: state %d, shifting to state %d\n",
                                YYDEBUGSTR, yydepth, yystate, yyctable[ctry]);
#endif
            if (yychar < 0)
            {
                yylvp++;
#if defined(YYLTYPE) || defined(YYLTYPE_IS_DECLARED)
                yylpp++;
#endif
                yylexp++;
            }
            if (yystack.s_mark >= yystack.s_last && yygrowstack(&yystack) == YYENOMEM)
                goto yyoverflow;
            yystate = yyctable[ctry];
            *++yystack.s_mark = (YYINT) yystate;
            *++yystack.l_mark = yylval;
#if defined(YYLTYPE) || defined(YYLTYPE_IS_DECLARED)
            *++yystack.p_mark = yylloc;
#endif
            yychar  = YYEMPTY;
            if (yyerrflag > 0) --yyerrflag;
            goto yyloop;
        }
        else
        {
            yyn = yyctable[ctry];
            goto yyreduce;
        }
    } /* End of code dealing with conflicts */
#endif /* YYBTYACC */
    if (((yyn = yysindex[yystate]) != 0) && (yyn += yychar) >= 0 &&
            yyn <= YYTABLESIZE && yycheck[yyn] == (YYINT) yychar)
    {
#if YYDEBUG
        if (yydebug)
            fprintf(stderr, "%s[%d]: state %d, shifting to state %d\n",
                            YYDEBUGSTR, yydepth, yystate, yytable[yyn]);
#endif
        if (yystack.s_mark >= yystack.s_last && yygrowstack(&yystack) == YYENOMEM) goto yyoverflow;
        yystate = yytable[yyn];
        *++yystack.s_mark = yytable[yyn];
        *++yystack.l_mark = yylval;
#if defined(YYLTYPE) || defined(YYLTYPE_IS_DECLARED)
        *++yystack.p_mark = yylloc;
#endif
        yychar = YYEMPTY;
        if (yyerrflag > 0)  --yyerrflag;
        goto yyloop;
    }
    if (((yyn = yyrindex[yystate]) != 0) && (yyn += yychar) >= 0 &&
            yyn <= YYTABLESIZE && yycheck[yyn] == (YYINT) yychar)
    {
        yyn = yytable[yyn];
        goto yyreduce;
    }
    if (yyerrflag != 0) goto yyinrecovery;
#if YYBTYACC

    yynewerrflag = 1;
    goto yyerrhandler;
    goto yyerrlab; /* redundant goto avoids 'unused label' warning */

yyerrlab:
    /* explicit YYERROR from an action -- pop the rhs of the rule reduced
     * before looking for error recovery */
    yystack.s_mark -= yym;
    yystate = *yystack.s_mark;
    yystack.l_mark -= yym;
#if defined(YYLTYPE) || defined(YYLTYPE_IS_DECLARED)
    yystack.p_mark -= yym;
#endif

    yynewerrflag = 0;
yyerrhandler:
    while (yyps->save)
    {
        int ctry;
        YYParseState *save = yyps->save;
#if YYDEBUG
        if (yydebug)
            fprintf(stderr, "%s[%d]: ERROR in state %d, CONFLICT BACKTRACKING to state %d, %d tokens\n",
                            YYDEBUGSTR, yydepth, yystate, yyps->save->state,
                    (int)(yylvp - yylvals - yyps->save->lexeme));
#endif
        /* Memorize most forward-looking error state in case it's really an error. */
        if (yyerrctx == NULL || yyerrctx->lexeme < yylvp - yylvals)
        {
            /* Free old saved error context state */
            if (yyerrctx) yyFreeState(yyerrctx);
            /* Create and fill out new saved error context state */
            yyerrctx                 = yyNewState((unsigned)(yystack.s_mark - yystack.s_base + 1));
            if (yyerrctx == NULL) goto yyenomem;
            yyerrctx->save           = yyps->save;
            yyerrctx->state          = yystate;
            yyerrctx->errflag        = yyerrflag;
            yyerrctx->yystack.s_mark = yyerrctx->yystack.s_base + (yystack.s_mark - yystack.s_base);
            memcpy (yyerrctx->yystack.s_base, yystack.s_base, (size_t) (yystack.s_mark - yystack.s_base + 1) * sizeof(YYINT));
            yyerrctx->yystack.l_mark = yyerrctx->yystack.l_base + (yystack.l_mark - yystack.l_base);
            memcpy (yyerrctx->yystack.l_base, yystack.l_base, (size_t) (yystack.l_mark - yystack.l_base + 1) * sizeof(YYSTYPE));
#if defined(YYLTYPE) || defined(YYLTYPE_IS_DECLARED)
            yyerrctx->yystack.p_mark = yyerrctx->yystack.p_base + (yystack.p_mark - yystack.p_base);
            memcpy (yyerrctx->yystack.p_base, yystack.p_base, (size_t) (yystack.p_mark - yystack.p_base + 1) * sizeof(YYLTYPE));
#endif
            yyerrctx->lexeme         = (int) (yylvp - yylvals);
        }
        yylvp          = yylvals   + save->lexeme;
#if defined(YYLTYPE) || defined(YYLTYPE_IS_DECLARED)
        yylpp          = yylpsns   + save->lexeme;
#endif
        yylexp         = yylexemes + save->lexeme;
        yychar         = YYEMPTY;
        yystack.s_mark = yystack.s_base + (save->yystack.s_mark - save->yystack.s_base);
        memcpy (yystack.s_base, save->yystack.s_base, (size_t) (yystack.s_mark - yystack.s_base + 1) * sizeof(YYINT));
        yystack.l_mark = yystack.l_base + (save->yystack.l_mark - save->yystack.l_base);
        memcpy (yystack.l_base, save->yystack.l_base, (size_t) (yystack.l_mark - yystack.l_base + 1) * sizeof(YYSTYPE));
#if defined(YYLTYPE) || defined(YYLTYPE_IS_DECLARED)
        yystack.p_mark = yystack.p_base + (save->yystack.p_mark - save->yystack.p_base);
        memcpy (yystack.p_base, save->yystack.p_base, (size_t) (yystack.p_mark - yystack.p_base + 1) * sizeof(YYLTYPE));
#endif
        ctry           = ++save->ctry;
        yystate        = save->state;
        /* We tried shift, try reduce now */
        if ((yyn = yyctable[ctry]) >= 0) goto yyreduce;
        yyps->save     = save->save;
        save->save     = NULL;
        yyFreeState(save);

        /* Nothing left on the stack -- error */
        if (!yyps->save)
        {
#if YYDEBUG
            if (yydebug)
                fprintf(stderr, "%sdebug[%d,trial]: trial parse FAILED, entering ERROR mode\n",
                                YYPREFIX, yydepth);
#endif
            /* Restore state as it was in the most forward-advanced error */
            yylvp          = yylvals   + yyerrctx->lexeme;
#if defined(YYLTYPE) || defined(YYLTYPE_IS_DECLARED)
            yylpp          = yylpsns   + yyerrctx->lexeme;
#endif
            yylexp         = yylexemes + yyerrctx->lexeme;
            yychar         = yylexp[-1];
            yylval         = yylvp[-1];
#if defined(YYLTYPE) || defined(YYLTYPE_IS_DECLARED)
            yylloc         = yylpp[-1];
#endif
            yystack.s_mark = yystack.s_base + (yyerrctx->yystack.s_mark - yyerrctx->yystack.s_base);
            memcpy (yystack.s_base, yyerrctx->yystack.s_base, (size_t) (yystack.s_mark - yystack.s_base + 1) * sizeof(YYINT));
            yystack.l_mark = yystack.l_base + (yyerrctx->yystack.l_mark - yyerrctx->yystack.l_base);
            memcpy (yystack.l_base, yyerrctx->yystack.l_base, (size_t) (yystack.l_mark - yystack.l_base + 1) * sizeof(YYSTYPE));
#if defined(YYLTYPE) || defined(YYLTYPE_IS_DECLARED)
            yystack.p_mark = yystack.p_base + (yyerrctx->yystack.p_mark - yyerrctx->yystack.p_base);
            memcpy (yystack.p_base, yyerrctx->yystack.p_base, (size_t) (yystack.p_mark - yystack.p_base + 1) * sizeof(YYLTYPE));
#endif
            yystate        = yyerrctx->state;
            yyFreeState(yyerrctx);
            yyerrctx       = NULL;
        }
        yynewerrflag = 1;
    }
    if (yynewerrflag == 0) goto yyinrecovery;
#endif /* YYBTYACC */

    YYERROR_CALL("syntax error");
#if defined(YYLTYPE) || defined(YYLTYPE_IS_DECLARED)
    yyerror_loc_range[1] = yylloc; /* lookahead position is error start position */
#endif

#if !YYBTYACC
    goto yyerrlab; /* redundant goto avoids 'unused label' warning */
yyerrlab:
#endif
    ++yynerrs;

yyinrecovery:
    if (yyerrflag < 3)
    {
        yyerrflag = 3;
        for (;;)
        {
            if (((yyn = yysindex[*yystack.s_mark]) != 0) && (yyn += YYERRCODE) >= 0 &&
                    yyn <= YYTABLESIZE && yycheck[yyn] == (YYINT) YYERRCODE)
            {
#if YYDEBUG
                if (yydebug)
                    fprintf(stderr, "%s[%d]: state %d, error recovery shifting to state %d\n",
                                    YYDEBUGSTR, yydepth, *yystack.s_mark, yytable[yyn]);
#endif
                if (yystack.s_mark >= yystack.s_last && yygrowstack(&yystack) == YYENOMEM) goto yyoverflow;
                yystate = yytable[yyn];
                *++yystack.s_mark = yytable[yyn];
                *++yystack.l_mark = yylval;
#if defined(YYLTYPE) || defined(YYLTYPE_IS_DECLARED)
                /* lookahead position is error end position */
                yyerror_loc_range[2] = yylloc;
                YYLLOC_DEFAULT(yyloc, yyerror_loc_range, 2); /* position of error span */
                *++yystack.p_mark = yyloc;
#endif
                goto yyloop;
            }
            else
            {
#if YYDEBUG
                if (yydebug)
                    fprintf(stderr, "%s[%d]: error recovery discarding state %d\n",
                                    YYDEBUGSTR, yydepth, *yystack.s_mark);
#endif
                if (yystack.s_mark <= yystack.s_base) goto yyabort;
#if defined(YYLTYPE) || defined(YYLTYPE_IS_DECLARED)
                /* the current TOS position is the error start position */
                yyerror_loc_range[1] = *yystack.p_mark;
#endif
#if defined(YYDESTRUCT_CALL)
#if YYBTYACC
                if (!yytrial)
#endif /* YYBTYACC */
#if defined(YYLTYPE) || defined(YYLTYPE_IS_DECLARED)
                    YYDESTRUCT_CALL("error: discarding state",
                                    yystos[*yystack.s_mark], yystack.l_mark, yystack.p_mark);
#else
                    YYDESTRUCT_CALL("error: discarding state",
                                    yystos[*yystack.s_mark], yystack.l_mark);
#endif /* defined(YYLTYPE) || defined(YYLTYPE_IS_DECLARED) */
#endif /* defined(YYDESTRUCT_CALL) */
                --yystack.s_mark;
                --yystack.l_mark;
#if defined(YYLTYPE) || defined(YYLTYPE_IS_DECLARED)
                --yystack.p_mark;
#endif
            }
        }
    }
    else
    {
        if (yychar == YYEOF) goto yyabort;
#if YYDEBUG
        if (yydebug)
        {
            if ((yys = yyname[YYTRANSLATE(yychar)]) == NULL) yys = yyname[YYUNDFTOKEN];
            fprintf(stderr, "%s[%d]: state %d, error recovery discarding token %d (%s)\n",
                            YYDEBUGSTR, yydepth, yystate, yychar, yys);
        }
#endif
#if defined(YYDESTRUCT_CALL)
#if YYBTYACC
        if (!yytrial)
#endif /* YYBTYACC */
#if defined(YYLTYPE) || defined(YYLTYPE_IS_DECLARED)
            YYDESTRUCT_CALL("error: discarding token", yychar, &yylval, &yylloc);
#else
            YYDESTRUCT_CALL("error: discarding token", yychar, &yylval);
#endif /* defined(YYLTYPE) || defined(YYLTYPE_IS_DECLARED) */
#endif /* defined(YYDESTRUCT_CALL) */
        yychar = YYEMPTY;
        goto yyloop;
    }

yyreduce:
    yym = yylen[yyn];
#if YYDEBUG
    if (yydebug)
    {
        fprintf(stderr, "%s[%d]: state %d, reducing by rule %d (%s)",
                        YYDEBUGSTR, yydepth, yystate, yyn, yyrule[yyn]);
#ifdef YYSTYPE_TOSTRING
#if YYBTYACC
        if (!yytrial)
#endif /* YYBTYACC */
            if (yym > 0)
            {
                int i;
                fputc('<', stderr);
                for (i = yym; i > 0; i--)
                {
                    if (i != yym) fputs(", ", stderr);
                    fputs(YYSTYPE_TOSTRING(yystos[yystack.s_mark[1-i]],
                                           yystack.l_mark[1-i]), stderr);
                }
                fputc('>', stderr);
            }
#endif
        fputc('\n', stderr);
    }
#endif
    if (yym > 0)
        yyval = yystack.l_mark[1-yym];
    else
        memset(&yyval, 0, sizeof yyval);
#if defined(YYLTYPE) || defined(YYLTYPE_IS_DECLARED)

    /* Perform position reduction */
    memset(&yyloc, 0, sizeof(yyloc));
#if YYBTYACC
    if (!yytrial)
#endif /* YYBTYACC */
    {
        YYLLOC_DEFAULT(yyloc, &yystack.p_mark[-yym], yym);
        /* just in case YYERROR is invoked within the action, save
           the start of the rhs as the error start position */
        yyerror_loc_range[1] = yystack.p_mark[1-yym];
    }
#endif

    switch (yyn)
    {
case 1:
#line 188 "parser.y"
	{
		print_grammar_rule("start", "program");
		yyval.symbol_info = new SymbolInfo("", "start");
		yyval.symbol_info->set_rule("start : program");
		yyval.symbol_info->add_child(yystack.l_mark[0].symbol_info);
		yyval.symbol_info->print_tree_node(treeout);
		yyval.symbol_info->delete_tree();
		free_s(yyval.symbol_info);
	}
#line 1448 "y.tab.c"
break;
case 2:
#line 199 "parser.y"
	{
		print_grammar_rule("program", "program unit");
		yyval.symbol_info = new SymbolInfo("", "program");	
		yyval.symbol_info->set_rule("program : program unit");
		yyval.symbol_info->add_child(yystack.l_mark[-1].symbol_info); yyval.symbol_info->add_child(yystack.l_mark[0].symbol_info);
	}
#line 1458 "y.tab.c"
break;
case 3:
#line 205 "parser.y"
	{
		print_grammar_rule("program", "unit");
		yyval.symbol_info = new SymbolInfo("", "program");
		yyval.symbol_info->set_rule("program : unit");
		yyval.symbol_info->add_child(yystack.l_mark[0].symbol_info);
	}
#line 1468 "y.tab.c"
break;
case 4:
#line 213 "parser.y"
	{
		print_grammar_rule("unit", "var_declaration");
		yyval.symbol_info = new SymbolInfo("", "unit");
		yyval.symbol_info->set_rule("unit : var_declaration");
		yyval.symbol_info->add_child(yystack.l_mark[0].symbol_info);
	}
#line 1478 "y.tab.c"
break;
case 5:
#line 219 "parser.y"
	{
		print_grammar_rule("unit", "func_declaration");
		yyval.symbol_info = new SymbolInfo("", "unit");
		yyval.symbol_info->set_rule("unit : func_declaration");
		yyval.symbol_info->add_child(yystack.l_mark[0].symbol_info);
	}
#line 1488 "y.tab.c"
break;
case 6:
#line 225 "parser.y"
	{
		print_grammar_rule("unit", "func_definition");
		yyval.symbol_info = new SymbolInfo("", "unit");
		yyval.symbol_info->set_rule("unit : func_definition");
		yyval.symbol_info->add_child(yystack.l_mark[0].symbol_info);
	}
#line 1498 "y.tab.c"
break;
case 7:
#line 231 "parser.y"
	{
		yyclearin; /* clears the lookahead*/
		yyerrok; /* now you can start normal parsing*/
		show_error(SYNTAX, S_UNIT, "", errorout);
		yyval.symbol_info = new SymbolInfo("", "unit");
	}
#line 1508 "y.tab.c"
break;
case 8:
#line 239 "parser.y"
	{
		print_grammar_rule("func_declaration", "type_specifier ID LPAREN parameter_list RPAREN SEMICOLON");
		reset_current_parameters(); /* resetting for this function*/
		yyval.symbol_info = new SymbolInfo("", "func_declaration");
		insert_function(yystack.l_mark[-4].symbol_info->get_name(), yystack.l_mark[-5].symbol_info->get_data_type(), yystack.l_mark[-2].symbol_info->get_param_list(), false);
		yyval.symbol_info->set_rule("func_declaration : type_specifier ID LPAREN parameter_list RPAREN SEMICOLON");
		yyval.symbol_info->add_child(yystack.l_mark[-5].symbol_info); yyval.symbol_info->add_child(yystack.l_mark[-4].symbol_info); yyval.symbol_info->add_child(yystack.l_mark[-3].symbol_info); yyval.symbol_info->add_child(yystack.l_mark[-2].symbol_info); yyval.symbol_info->add_child(yystack.l_mark[-1].symbol_info); yyval.symbol_info->add_child(yystack.l_mark[0].symbol_info);
	}
#line 1520 "y.tab.c"
break;
case 9:
#line 247 "parser.y"
	{
		print_grammar_rule("func_declaration", "type_specifier ID LPAREN RPAREN SEMICOLON");
		reset_current_parameters();
		yyval.symbol_info = new SymbolInfo("", "func_declaration");
		insert_function(yystack.l_mark[-4].symbol_info->get_name(), yystack.l_mark[-5].symbol_info->get_data_type(), {}, false);
		yyval.symbol_info->set_rule("func_declaration : type_specifier ID LPAREN RPAREN SEMICOLON");
		yyval.symbol_info->add_child(yystack.l_mark[-5].symbol_info); yyval.symbol_info->add_child(yystack.l_mark[-4].symbol_info); yyval.symbol_info->add_child(yystack.l_mark[-3].symbol_info); yyval.symbol_info->add_child(yystack.l_mark[-1].symbol_info); yyval.symbol_info->add_child(yystack.l_mark[0].symbol_info);
	}
#line 1532 "y.tab.c"
break;
case 10:
#line 255 "parser.y"
	{
		print_grammar_rule("func_declaration", "type_specifier ID LPAREN RPAREN SEMICOLON");
		reset_current_parameters();
		yyval.symbol_info = new SymbolInfo("", "func_declaration");
		insert_function(yystack.l_mark[-3].symbol_info->get_name(), yystack.l_mark[-4].symbol_info->get_data_type(), {}, false);
		yyval.symbol_info->set_rule("func_declaration : type_specifier ID LPAREN RPAREN SEMICOLON");
		yyval.symbol_info->add_child(yystack.l_mark[-4].symbol_info); yyval.symbol_info->add_child(yystack.l_mark[-3].symbol_info); yyval.symbol_info->add_child(yystack.l_mark[-2].symbol_info); yyval.symbol_info->add_child(yystack.l_mark[-1].symbol_info); yyval.symbol_info->add_child(yystack.l_mark[0].symbol_info);
	}
#line 1544 "y.tab.c"
break;
case 11:
#line 265 "parser.y"
	{ insert_function(yystack.l_mark[-3].symbol_info->get_name(), yystack.l_mark[-4].symbol_info->get_data_type(), yystack.l_mark[-1].symbol_info->get_param_list(), true); }
#line 1549 "y.tab.c"
break;
case 12:
#line 265 "parser.y"
	{
		print_grammar_rule("func_definition", "type_specifier ID LPAREN parameter_list RPAREN compound_statement");
		yyval.symbol_info = new SymbolInfo("", "func_definition");
		yyval.symbol_info->set_rule("func_definition : type_specifier ID LPAREN parameter_list RPAREN compound_statement");
		yyval.symbol_info->add_child(yystack.l_mark[-6].symbol_info); yyval.symbol_info->add_child(yystack.l_mark[-5].symbol_info); yyval.symbol_info->add_child(yystack.l_mark[-4].symbol_info); yyval.symbol_info->add_child(yystack.l_mark[-3].symbol_info); yyval.symbol_info->add_child(yystack.l_mark[-2].symbol_info); yyval.symbol_info->add_child(comp_statement);
	}
#line 1559 "y.tab.c"
break;
case 13:
#line 271 "parser.y"
	{ insert_function(yystack.l_mark[-3].symbol_info->get_name(), yystack.l_mark[-4].symbol_info->get_data_type(), {}, true); }
#line 1564 "y.tab.c"
break;
case 14:
#line 271 "parser.y"
	{
		print_grammar_rule("func_definition", "type_specifier ID LPAREN parameter_list RPAREN compound_statement");
		yyval.symbol_info = new SymbolInfo("", "func_definition");
		show_error(SYNTAX, S_PARAM_FUNC_DEFINITION, "", errorout);
		yyval.symbol_info->set_rule("func_definition : type_specifier ID LPAREN RPAREN compound_statement");
		yyval.symbol_info->add_child(yystack.l_mark[-6].symbol_info); yyval.symbol_info->add_child(yystack.l_mark[-5].symbol_info); yyval.symbol_info->add_child(yystack.l_mark[-4].symbol_info); yyval.symbol_info->add_child(yystack.l_mark[-2].symbol_info); yyval.symbol_info->add_child(comp_statement);
	}
#line 1575 "y.tab.c"
break;
case 15:
#line 278 "parser.y"
	{ insert_function(yystack.l_mark[-2].symbol_info->get_name(), yystack.l_mark[-3].symbol_info->get_data_type(), {}, true); }
#line 1580 "y.tab.c"
break;
case 16:
#line 278 "parser.y"
	{
		print_grammar_rule("func_definition", "type_specifier ID LPAREN RPAREN compound_statement");
		yyval.symbol_info = new SymbolInfo("", "func_definition");
		yyval.symbol_info->set_rule("func_definition : type_specifier ID LPAREN RPAREN compound_statement");
		yyval.symbol_info->add_child(yystack.l_mark[-5].symbol_info); yyval.symbol_info->add_child(yystack.l_mark[-4].symbol_info); yyval.symbol_info->add_child(yystack.l_mark[-3].symbol_info); yyval.symbol_info->add_child(yystack.l_mark[-2].symbol_info); yyval.symbol_info->add_child(comp_statement);
	}
#line 1590 "y.tab.c"
break;
case 17:
#line 286 "parser.y"
	{
		print_grammar_rule("parameter_list", "parameter_list COMMA type_specifier ID");
		yyval.symbol_info = new SymbolInfo("", "parameter_list");
		yyval.symbol_info->set_param_list(yystack.l_mark[-3].symbol_info->get_param_list());
		yyval.symbol_info->add_param(yystack.l_mark[0].symbol_info->get_name(), yystack.l_mark[-1].symbol_info->get_data_type());
		check_type_specifier(yystack.l_mark[-1].symbol_info, yystack.l_mark[0].symbol_info->get_name());
		copy_func_parameters(yyval.symbol_info);
		yyval.symbol_info->set_rule("parameter_list : parameter_list COMMA type_specifier ID");
		yyval.symbol_info->add_child(yystack.l_mark[-3].symbol_info); yyval.symbol_info->add_child(yystack.l_mark[-2].symbol_info); yyval.symbol_info->add_child(yystack.l_mark[-1].symbol_info); yyval.symbol_info->add_child(yystack.l_mark[0].symbol_info);
	}
#line 1604 "y.tab.c"
break;
case 18:
#line 296 "parser.y"
	{
		print_grammar_rule("parameter_list", "parameter_list COMMA type_specifier");
		yyval.symbol_info = new SymbolInfo("", "parameter_list");
		yyval.symbol_info->set_param_list(yystack.l_mark[-2].symbol_info->get_param_list());
		yyval.symbol_info->add_param("", yystack.l_mark[0].symbol_info->get_data_type()); /* later check if this nameless parameter is used in function definition. if yes, then show error*/
		check_type_specifier(yystack.l_mark[0].symbol_info, "");
		copy_func_parameters(yyval.symbol_info);
		yyval.symbol_info->set_rule("parameter_list : parameter_list COMMA type_specifier");
		yyval.symbol_info->add_child(yystack.l_mark[-2].symbol_info); yyval.symbol_info->add_child(yystack.l_mark[-1].symbol_info); yyval.symbol_info->add_child(yystack.l_mark[0].symbol_info);
	}
#line 1618 "y.tab.c"
break;
case 19:
#line 306 "parser.y"
	{
		print_grammar_rule("parameter_list", "type_specifier ID");
		yyval.symbol_info = new SymbolInfo("", "parameter_list");
		yyval.symbol_info->add_param(yystack.l_mark[0].symbol_info->get_name(), yystack.l_mark[-1].symbol_info->get_data_type());
		check_type_specifier(yystack.l_mark[-1].symbol_info, yystack.l_mark[0].symbol_info->get_name());
		copy_func_parameters(yyval.symbol_info);
		yyval.symbol_info->set_rule("parameter_list : type_specifier ID");
		yyval.symbol_info->add_child(yystack.l_mark[-1].symbol_info); yyval.symbol_info->add_child(yystack.l_mark[0].symbol_info);
	}
#line 1631 "y.tab.c"
break;
case 20:
#line 315 "parser.y"
	{
		print_grammar_rule("parameter_list", "type_specifier");
		yyval.symbol_info = new SymbolInfo("", "parameter_list");
		yyval.symbol_info->add_param("", yystack.l_mark[0].symbol_info->get_data_type()); /* later check if this nameless parameter is used in function definition. if yes, then show error*/
		check_type_specifier(yystack.l_mark[0].symbol_info, "");
		copy_func_parameters(yyval.symbol_info);
		yyval.symbol_info->set_rule("parameter_list : type_specifier");
		yyval.symbol_info->add_child(yystack.l_mark[0].symbol_info);
	}
#line 1644 "y.tab.c"
break;
case 21:
#line 326 "parser.y"
	{
		print_grammar_rule("compound_statement", "LCURL statements RCURL");
		yyval.symbol_info = new SymbolInfo("", "compound_statement");
		comp_statement = yyval.symbol_info;
		sym->print('A', logout);
		sym->exit_scope();
		yyval.symbol_info->set_rule("compound_statement : LCURL statements RCURL");
		yyval.symbol_info->add_child(yystack.l_mark[-2].symbol_info); yyval.symbol_info->add_child(yystack.l_mark[-1].symbol_info); yyval.symbol_info->add_child(yystack.l_mark[0].symbol_info);
	}
#line 1657 "y.tab.c"
break;
case 22:
#line 335 "parser.y"
	{
		print_grammar_rule("compound_statement", "LCURL RCURL");
		yyval.symbol_info = new SymbolInfo("", "compound_statement");
		comp_statement = yyval.symbol_info;
		sym->print('A', logout);
		sym->exit_scope();
		yyval.symbol_info->set_rule("compound_statement : LCURL RCURL");
		yyval.symbol_info->add_child(yystack.l_mark[-2].symbol_info); yyval.symbol_info->add_child(yystack.l_mark[0].symbol_info);
	}
#line 1670 "y.tab.c"
break;
case 23:
#line 344 "parser.y"
	{
		print_grammar_rule("compound_statement", "LCURL RCURL");
		yyval.symbol_info = new SymbolInfo("", "compound_statement");
		comp_statement = yyval.symbol_info;
		sym->print('A', logout);
		sym->exit_scope();
		yyval.symbol_info->set_rule("compound_statement : LCURL RCURL");
		yyval.symbol_info->add_child(yystack.l_mark[-1].symbol_info); yyval.symbol_info->add_child(yystack.l_mark[0].symbol_info);
	}
#line 1683 "y.tab.c"
break;
case 24:
#line 355 "parser.y"
	{
		print_grammar_rule("var_declaration", "type_specifier declaration_list SEMICOLON");
		yyval.symbol_info = new SymbolInfo("", "var_declaration", yystack.l_mark[-2].symbol_info->get_data_type());
		string str = "";
		vector<Param> cur_list = yystack.l_mark[-1].symbol_info->get_param_list();
		for (int i = 0; i < cur_list.size(); i++) {
			str += cur_list[i].name;
			if (i != cur_list.size() - 1) str += ", ";
		}
		bool ok = check_type_specifier(yystack.l_mark[-2].symbol_info, str);
		if (ok) {
			for (int i = 0; i < cur_list.size(); i++) {
				/* now we will set the data_type of all these symbols to $1*/
				cur_list[i].data_type = yystack.l_mark[-2].symbol_info->get_data_type();
				/* cerr << cur_list[i].data_type << " " << cur_list[i].name << endl;*/
				SymbolInfo* res = sym->search(cur_list[i].name, 'C');
				if (res == nullptr) {
					SymbolInfo* new_sym = new SymbolInfo(cur_list[i].name, "ID", cur_list[i].data_type);
					if (cur_list[i].is_array) new_sym->set_array(true);
					sym->insert(new_sym);
				}
				else if (res->get_data_type() != cur_list[i].data_type) {
					/* cerr << "Previous: " << res->get_data_type() << " current: " << cur_list[i].data_type << " " << cur_list[i].name << " line: " << line_count << endl; */
					show_error(SEMANTIC, CONFLICTING_TYPE, cur_list[i].name, errorout);
				}
				else {
					show_error(SEMANTIC, VARIABLE_REDEFINITION, cur_list[i].name, errorout);
				}
			}
		}
		yyval.symbol_info->set_rule("var_declaration : type_specifier declaration_list SEMICOLON");
		yyval.symbol_info->add_child(yystack.l_mark[-2].symbol_info); yyval.symbol_info->add_child(yystack.l_mark[-1].symbol_info); yyval.symbol_info->add_child(yystack.l_mark[0].symbol_info);
	}
#line 1720 "y.tab.c"
break;
case 25:
#line 388 "parser.y"
	{
		print_grammar_rule("var_declaration", "type_specifier declaration_list SEMICOLON");
		yyval.symbol_info = new SymbolInfo("", "var_declaration");
		yyclearin;
		yyerrok;
		show_error(SYNTAX, S_DECL_VAR_DECLARATION, "", errorout);
		yyval.symbol_info->set_rule("var_declaration : type_specifier SEMICOLON");
		yyval.symbol_info->add_child(yystack.l_mark[-2].symbol_info); yyval.symbol_info->add_child(yystack.l_mark[0].symbol_info);
	}
#line 1733 "y.tab.c"
break;
case 26:
#line 399 "parser.y"
	{
		print_grammar_rule("type_specifier", "INT");
		yyval.symbol_info = new SymbolInfo("", "type_specifier", "int");
		yyval.symbol_info->set_rule("type_specifier : INT");
		yyval.symbol_info->add_child(yystack.l_mark[0].symbol_info);
	}
#line 1743 "y.tab.c"
break;
case 27:
#line 405 "parser.y"
	{
		print_grammar_rule("type_specifier", "FLOAT");
		yyval.symbol_info = new SymbolInfo("", "type_specifier", "float");
		yyval.symbol_info->set_rule("type_specifier : FLOAT");
		yyval.symbol_info->add_child(yystack.l_mark[0].symbol_info);
	}
#line 1753 "y.tab.c"
break;
case 28:
#line 411 "parser.y"
	{
		print_grammar_rule("type_specifier", "VOID");
		yyval.symbol_info = new SymbolInfo("", "type_specifier", "void");
		yyval.symbol_info->set_rule("type_specifier : VOID");
		yyval.symbol_info->add_child(yystack.l_mark[0].symbol_info);
	}
#line 1763 "y.tab.c"
break;
case 29:
#line 419 "parser.y"
	{
		print_grammar_rule("declaration_list", "declaration_list COMMA ID");
		yyval.symbol_info = new SymbolInfo("", "declaration_list");
		yyval.symbol_info->set_param_list(yystack.l_mark[-2].symbol_info->get_param_list());
		yyval.symbol_info->add_param(yystack.l_mark[0].symbol_info->get_name(), "");
		yyval.symbol_info->set_rule("declaration_list : declaration_list COMMA ID");
		yyval.symbol_info->add_child(yystack.l_mark[-2].symbol_info); yyval.symbol_info->add_child(yystack.l_mark[-1].symbol_info); yyval.symbol_info->add_child(yystack.l_mark[0].symbol_info);
	}
#line 1775 "y.tab.c"
break;
case 30:
#line 427 "parser.y"
	{
		print_grammar_rule("declaration_list", "declaration_list COMMA ID LSQUARE CONST_INT RSQUARE");
		yyval.symbol_info = new SymbolInfo("", "declaration_list");
		yyval.symbol_info->set_param_list(yystack.l_mark[-5].symbol_info->get_param_list());
		yyval.symbol_info->add_param(yystack.l_mark[-3].symbol_info->get_name(), "ID", true);
		yyval.symbol_info->set_rule("declaration_list : declaration_list COMMA ID LSQUARE CONST_INT RSQUARE");
		yyval.symbol_info->add_child(yystack.l_mark[-5].symbol_info); yyval.symbol_info->add_child(yystack.l_mark[-4].symbol_info); yyval.symbol_info->add_child(yystack.l_mark[-3].symbol_info); yyval.symbol_info->add_child(yystack.l_mark[-2].symbol_info); yyval.symbol_info->add_child(yystack.l_mark[-1].symbol_info); yyval.symbol_info->add_child(yystack.l_mark[0].symbol_info);
	}
#line 1787 "y.tab.c"
break;
case 31:
#line 435 "parser.y"
	{
		print_grammar_rule("declaration_list", "ID");
		yyval.symbol_info = new SymbolInfo("", "declaration_list");
		yyval.symbol_info->add_param(yystack.l_mark[0].symbol_info->get_name(), "ID");
		yyval.symbol_info->set_rule("declaration_list : ID");
		yyval.symbol_info->add_child(yystack.l_mark[0].symbol_info);
	}
#line 1798 "y.tab.c"
break;
case 32:
#line 442 "parser.y"
	{
		print_grammar_rule("declaration_list", "ID LSQUARE CONST_INT RSQUARE");
		yyval.symbol_info = new SymbolInfo("", "declaration_list");
		yyval.symbol_info->add_param(yystack.l_mark[-3].symbol_info->get_name(), "ID", true);
		yyval.symbol_info->set_rule("declaration_list : ID LSQUARE CONST_INT RSQUARE");
		yyval.symbol_info->add_child(yystack.l_mark[-3].symbol_info); yyval.symbol_info->add_child(yystack.l_mark[-2].symbol_info); yyval.symbol_info->add_child(yystack.l_mark[-1].symbol_info); yyval.symbol_info->add_child(yystack.l_mark[0].symbol_info);
	}
#line 1809 "y.tab.c"
break;
case 33:
#line 451 "parser.y"
	{
		print_grammar_rule("statements", "statement");
		yyval.symbol_info = new SymbolInfo(yystack.l_mark[0].symbol_info->get_name(), "statements");
		yyval.symbol_info->set_rule("statements : statement");
		yyval.symbol_info->add_child(yystack.l_mark[0].symbol_info);
	}
#line 1819 "y.tab.c"
break;
case 34:
#line 457 "parser.y"
	{
		print_grammar_rule("statements", "statements statement");
		yyval.symbol_info = new SymbolInfo(yystack.l_mark[-1].symbol_info->get_name(), "statements");
		yyval.symbol_info->set_rule("statements : statements statement");
		yyval.symbol_info->add_child(yystack.l_mark[-1].symbol_info); yyval.symbol_info->add_child(yystack.l_mark[0].symbol_info);
	}
#line 1829 "y.tab.c"
break;
case 35:
#line 465 "parser.y"
	{
		print_grammar_rule("statement", "var_declaration");
		yyval.symbol_info = new SymbolInfo(yystack.l_mark[0].symbol_info->get_name(), "statement", yystack.l_mark[0].symbol_info->get_data_type());
		yyval.symbol_info->set_rule("statement : var_declaration");
		yyval.symbol_info->add_child(yystack.l_mark[0].symbol_info);
	}
#line 1839 "y.tab.c"
break;
case 36:
#line 471 "parser.y"
	{
		print_grammar_rule("statement", "expression_statement");
		yyval.symbol_info = new SymbolInfo(yystack.l_mark[0].symbol_info->get_name(), "statement", yystack.l_mark[0].symbol_info->get_data_type());
		yyval.symbol_info->set_rule("statement : expression_statement");
		yyval.symbol_info->add_child(yystack.l_mark[0].symbol_info);
	}
#line 1849 "y.tab.c"
break;
case 37:
#line 477 "parser.y"
	{
		print_grammar_rule("statement", "compound_statement");
		yyval.symbol_info = new SymbolInfo(yystack.l_mark[0].symbol_info->get_name(), "statement", yystack.l_mark[0].symbol_info->get_data_type());
		yyval.symbol_info->set_rule("statement : compound_statement");
		yyval.symbol_info->add_child(yystack.l_mark[0].symbol_info);
	}
#line 1859 "y.tab.c"
break;
case 38:
#line 483 "parser.y"
	{
		print_grammar_rule("statement", "FOR LPAREN expression_statement expression_statement expression RPAREN statement");
		yyval.symbol_info = new SymbolInfo("", "statement");
		yyval.symbol_info->set_rule("statement : FOR LPAREN expression_statement expression_statement expression RPAREN statement");
		yyval.symbol_info->add_child(yystack.l_mark[-6].symbol_info); yyval.symbol_info->add_child(yystack.l_mark[-5].symbol_info); yyval.symbol_info->add_child(yystack.l_mark[-4].symbol_info); yyval.symbol_info->add_child(yystack.l_mark[-3].symbol_info); yyval.symbol_info->add_child(yystack.l_mark[-2].symbol_info); yyval.symbol_info->add_child(yystack.l_mark[-1].symbol_info); yyval.symbol_info->add_child(yystack.l_mark[0].symbol_info);
	}
#line 1869 "y.tab.c"
break;
case 39:
#line 489 "parser.y"
	{
		/* how did you resolve the conflict? check at book 189 page*/
		/* The precedence of the token to shift must be higher than the precedence of the rule to reduce, so %nonassoc ELSE must come after %nonassoc THEN or %nonassoc LOWER_THAN_ELSE*/
		print_grammar_rule("statement", "IF LPAREN expression RPAREN statement");
		yyval.symbol_info = new SymbolInfo("", "statement");
		yyval.symbol_info->set_rule("statement : IF LPAREN expression RPAREN statement");
		yyval.symbol_info->add_child(yystack.l_mark[-4].symbol_info); yyval.symbol_info->add_child(yystack.l_mark[-3].symbol_info); yyval.symbol_info->add_child(yystack.l_mark[-2].symbol_info); yyval.symbol_info->add_child(yystack.l_mark[-1].symbol_info); yyval.symbol_info->add_child(yystack.l_mark[0].symbol_info);
	}
#line 1881 "y.tab.c"
break;
case 40:
#line 497 "parser.y"
	{
		print_grammar_rule("statement", "IF LPAREN expression RPAREN statement ELSE statement");
		yyval.symbol_info = new SymbolInfo("", "statement");
		yyval.symbol_info->set_rule("statement : IF LPAREN expression RPAREN statement ELSE statement");
		yyval.symbol_info->add_child(yystack.l_mark[-6].symbol_info); yyval.symbol_info->add_child(yystack.l_mark[-5].symbol_info); yyval.symbol_info->add_child(yystack.l_mark[-4].symbol_info); yyval.symbol_info->add_child(yystack.l_mark[-3].symbol_info); yyval.symbol_info->add_child(yystack.l_mark[-2].symbol_info); yyval.symbol_info->add_child(yystack.l_mark[-1].symbol_info); yyval.symbol_info->add_child(yystack.l_mark[0].symbol_info);
	}
#line 1891 "y.tab.c"
break;
case 41:
#line 503 "parser.y"
	{
		print_grammar_rule("statement", "WHILE LPAREN expression RPAREN statement");
		yyval.symbol_info = new SymbolInfo("", "statement");
		yyval.symbol_info->set_rule("statement : WHILE LPAREN expression RPAREN statement");
		yyval.symbol_info->add_child(yystack.l_mark[-4].symbol_info); yyval.symbol_info->add_child(yystack.l_mark[-3].symbol_info); yyval.symbol_info->add_child(yystack.l_mark[-2].symbol_info); yyval.symbol_info->add_child(yystack.l_mark[-1].symbol_info); yyval.symbol_info->add_child(yystack.l_mark[0].symbol_info);
	}
#line 1901 "y.tab.c"
break;
case 42:
#line 509 "parser.y"
	{
		print_grammar_rule("statement", "PRINTLN LPAREN ID RPAREN SEMICOLON");
		yyval.symbol_info = new SymbolInfo("", "statement");
		if (sym->search(yystack.l_mark[-2].symbol_info->get_name(), 'A') == nullptr) {
			show_error(SEMANTIC, UNDECLARED_VARIABLE, yystack.l_mark[-2].symbol_info->get_name(), errorout);
		}
		yyval.symbol_info->set_rule("statement : PRINTLN LPAREN ID RPAREN SEMICOLON");
		yyval.symbol_info->add_child(yystack.l_mark[-4].symbol_info); yyval.symbol_info->add_child(yystack.l_mark[-3].symbol_info); yyval.symbol_info->add_child(yystack.l_mark[-2].symbol_info); yyval.symbol_info->add_child(yystack.l_mark[-1].symbol_info); yyval.symbol_info->add_child(yystack.l_mark[0].symbol_info);
	}
#line 1914 "y.tab.c"
break;
case 43:
#line 518 "parser.y"
	{
		print_grammar_rule("statement", "RETURN expression SEMICOLON");
		yyval.symbol_info = new SymbolInfo("", "statement");
		yyval.symbol_info->set_rule("statement : RETURN expression SEMICOLON");
		yyval.symbol_info->add_child(yystack.l_mark[-2].symbol_info); yyval.symbol_info->add_child(yystack.l_mark[-1].symbol_info); yyval.symbol_info->add_child(yystack.l_mark[0].symbol_info);
	}
#line 1924 "y.tab.c"
break;
case 44:
#line 526 "parser.y"
	{
		print_grammar_rule("expression_statement", "SEMICOLON");
		yyval.symbol_info = new SymbolInfo("", "expression_statement");
		yyval.symbol_info->set_rule("expression_statement : SEMICOLON");
		yyval.symbol_info->add_child(yystack.l_mark[0].symbol_info);
	}
#line 1934 "y.tab.c"
break;
case 45:
#line 532 "parser.y"
	{
		print_grammar_rule("expression_statement", "expression SEMICOLON");
		yyval.symbol_info = new SymbolInfo("", "expression_statement");
		yyval.symbol_info->set_data_type(yystack.l_mark[-1].symbol_info->get_data_type()); /* result of an expression will have a certain data type, won't it?*/
		yyval.symbol_info->set_rule("expression_statement : expression SEMICOLON");
		yyval.symbol_info->add_child(yystack.l_mark[-1].symbol_info); yyval.symbol_info->add_child(yystack.l_mark[0].symbol_info);
	}
#line 1945 "y.tab.c"
break;
case 46:
#line 539 "parser.y"
	{
		yyclearin; /* clear the lookahead token*/
		yyerrok; /* clear the error stack*/
		show_error(SYNTAX, S_EXP_STATEMENT, "", errorout);
		yyval.symbol_info = new SymbolInfo("", "expression_statement");
		free_s(yystack.l_mark[0].symbol_info);
	}
#line 1956 "y.tab.c"
break;
case 47:
#line 548 "parser.y"
	{
		print_grammar_rule("variable", "ID");
		yyval.symbol_info = new SymbolInfo(yystack.l_mark[0].symbol_info->get_name(), "VARIABLE", yystack.l_mark[0].symbol_info->get_data_type());
		
		SymbolInfo* res = sym->search(yystack.l_mark[0].symbol_info->get_name(), 'A');
		if (res == nullptr) {
			show_error(SEMANTIC, UNDECLARED_VARIABLE, yystack.l_mark[0].symbol_info->get_name(), errorout);
		}
		else {
			yyval.symbol_info->set_data_type(res->get_data_type());
			yyval.symbol_info->set_array(res->is_array());
		}
		yyval.symbol_info->set_rule("variable : ID");
		yyval.symbol_info->add_child(yystack.l_mark[0].symbol_info);
	}
#line 1975 "y.tab.c"
break;
case 48:
#line 563 "parser.y"
	{
		/* it has to be an array now*/
		print_grammar_rule("variable", "ID LSQUARE expression RSQUARE");
		yyval.symbol_info = new SymbolInfo(yystack.l_mark[-3].symbol_info->get_name(), "VARIABLE", yystack.l_mark[-3].symbol_info->get_data_type());
		
		SymbolInfo* res = sym->search(yystack.l_mark[-3].symbol_info->get_name(), 'A');
		if (res == nullptr) {
			show_error(SEMANTIC, UNDECLARED_VARIABLE, yystack.l_mark[-3].symbol_info->get_name(), errorout);
		}
		else if (!res->is_array()) {
			/* declared as a normal variable, but used like an array, so error*/
			show_error(SEMANTIC, ERROR_AS_ARRAY, yystack.l_mark[-3].symbol_info->get_name(), errorout);
		}
		else if (yystack.l_mark[-1].symbol_info->get_data_type() != "INT") {
			/* array index is not an integer, so error*/
			show_error(SEMANTIC, INDEX_NOT_INT, yystack.l_mark[-3].symbol_info->get_name(), errorout);
		}
		else {
			yyval.symbol_info->set_data_type(res->get_data_type());
			yyval.symbol_info->set_array(false); /* if a is an int array, a[5] is also an int, but not an array*/
		}
		yyval.symbol_info->set_rule("variable : ID LSQUARE expression RSQUARE");
		yyval.symbol_info->add_child(yystack.l_mark[-3].symbol_info); yyval.symbol_info->add_child(yystack.l_mark[-2].symbol_info); yyval.symbol_info->add_child(yystack.l_mark[-1].symbol_info); yyval.symbol_info->add_child(yystack.l_mark[0].symbol_info);
	}
#line 2003 "y.tab.c"
break;
case 49:
#line 589 "parser.y"
	{
		print_grammar_rule("expression", "logic_expression");
		yyval.symbol_info = new SymbolInfo(yystack.l_mark[0].symbol_info->get_name(), "expression", yystack.l_mark[0].symbol_info->get_data_type());
		yyval.symbol_info->set_array(yystack.l_mark[0].symbol_info->is_array());
		yyval.symbol_info->set_rule("expression : logic_expression");
		yyval.symbol_info->add_child(yystack.l_mark[0].symbol_info);
	}
#line 2014 "y.tab.c"
break;
case 50:
#line 596 "parser.y"
	{
		print_grammar_rule("expression", "variable ASSIGNOP logic_expression");
		yyval.symbol_info = new SymbolInfo("", "expression");
		if (yystack.l_mark[-2].symbol_info->get_data_type() == "VOID" || yystack.l_mark[0].symbol_info->get_data_type() == "VOID") {
			show_error(SEMANTIC, VOID_USAGE, "", errorout);
			yyval.symbol_info->set_data_type("ERROR");
		}
		else if (yystack.l_mark[-2].symbol_info->get_data_type() == "ERROR" || yystack.l_mark[0].symbol_info->get_data_type() == "ERROR") {
			show_error(SEMANTIC, TYPE_ERROR, "", errorout);
			yyval.symbol_info->set_data_type("ERROR");
		}
		else if (yystack.l_mark[-2].symbol_info->get_data_type() == "INT") {
			if (yystack.l_mark[0].symbol_info->get_data_type() == "FLOAT") {
				show_error(WARNING, FLOAT_TO_INT, "", errorout);
			}
			yyval.symbol_info->set_data_type("INT");
		}
		else {
			yyval.symbol_info->set_data_type("FLOAT");
		}
		yyval.symbol_info->set_rule("expression : variable ASSIGNOP logic_expression");
		yyval.symbol_info->add_child(yystack.l_mark[-2].symbol_info); yyval.symbol_info->add_child(yystack.l_mark[-1].symbol_info); yyval.symbol_info->add_child(yystack.l_mark[0].symbol_info);
	}
#line 2041 "y.tab.c"
break;
case 51:
#line 621 "parser.y"
	{
		print_grammar_rule("logic_expression", "rel_expression");
		yyval.symbol_info = new SymbolInfo(yystack.l_mark[0].symbol_info->get_name(), "logic_expression", yystack.l_mark[0].symbol_info->get_data_type());
		yyval.symbol_info->set_array(yystack.l_mark[0].symbol_info->is_array());
		yyval.symbol_info->set_rule("logic_expression : rel_expression");
		yyval.symbol_info->add_child(yystack.l_mark[0].symbol_info);
	}
#line 2052 "y.tab.c"
break;
case 52:
#line 628 "parser.y"
	{
		print_grammar_rule("logic_expression", "rel_expression LOGICOP rel_expression");
		yyval.symbol_info = new SymbolInfo("", "logic_expression");
		if (yystack.l_mark[-2].symbol_info->get_data_type() == "VOID" || yystack.l_mark[0].symbol_info->get_data_type() == "VOID") {
			show_error(SEMANTIC, VOID_USAGE, "", errorout);
			yyval.symbol_info->set_data_type("ERROR");
		}
		else if (yystack.l_mark[-2].symbol_info->get_data_type() == "ERROR" || yystack.l_mark[0].symbol_info->get_data_type() == "ERROR") {
			show_error(SEMANTIC, TYPE_ERROR, "", errorout);
			yyval.symbol_info->set_data_type("ERROR");
		}
		else if (yystack.l_mark[-2].symbol_info->get_data_type() == "FLOAT" || yystack.l_mark[0].symbol_info->get_data_type() == "FLOAT") {
			show_error(WARNING, LOGICAL_FLOAT, "", errorout);
			yyval.symbol_info->set_data_type("INT");
		}
		else {
			yyval.symbol_info->set_data_type("INT");
		}
		yyval.symbol_info->set_rule("logic_expression : rel_expression LOGICOP rel_expression");
		yyval.symbol_info->add_child(yystack.l_mark[-2].symbol_info); yyval.symbol_info->add_child(yystack.l_mark[-1].symbol_info); yyval.symbol_info->add_child(yystack.l_mark[0].symbol_info);
	}
#line 2077 "y.tab.c"
break;
case 53:
#line 651 "parser.y"
	{
		print_grammar_rule("rel_expression", "simple_expression");
		yyval.symbol_info = new SymbolInfo(yystack.l_mark[0].symbol_info->get_name(), "rel_expression", yystack.l_mark[0].symbol_info->get_data_type());
		yyval.symbol_info->set_array(yystack.l_mark[0].symbol_info->is_array()); /* will need in function argument type checking*/
		yyval.symbol_info->set_rule("rel_expression : simple_expression");
		yyval.symbol_info->add_child(yystack.l_mark[0].symbol_info);
	}
#line 2088 "y.tab.c"
break;
case 54:
#line 658 "parser.y"
	{
		print_grammar_rule("rel_expression", "simple_expression RELOP simple_expression");
		yyval.symbol_info = new SymbolInfo("", "rel_expression");
		if (yystack.l_mark[-2].symbol_info->get_data_type() == "VOID" || yystack.l_mark[0].symbol_info->get_data_type() == "VOID") {
			show_error(SEMANTIC, VOID_USAGE, "", errorout);
			yyval.symbol_info->set_data_type("ERROR");
		}
		else {
			yyval.symbol_info->set_data_type("INT"); /* result of any comparison should be boolean in fact*/
		}
		yyval.symbol_info->set_rule("rel_expression : simple_expression RELOP simple_expression");
		yyval.symbol_info->add_child(yystack.l_mark[-2].symbol_info); yyval.symbol_info->add_child(yystack.l_mark[-1].symbol_info); yyval.symbol_info->add_child(yystack.l_mark[0].symbol_info);
	}
#line 2105 "y.tab.c"
break;
case 55:
#line 673 "parser.y"
	{
		print_grammar_rule("simple_expression", "term");
		yyval.symbol_info = new SymbolInfo(yystack.l_mark[0].symbol_info->get_name(), "simple_expression", yystack.l_mark[0].symbol_info->get_data_type());
		yyval.symbol_info->set_array(yystack.l_mark[0].symbol_info->is_array());
		yyval.symbol_info->set_rule("simple_expression : term");
		yyval.symbol_info->add_child(yystack.l_mark[0].symbol_info);
	}
#line 2116 "y.tab.c"
break;
case 56:
#line 680 "parser.y"
	{
		print_grammar_rule("simple_expression", "simple_expression ADDOP term");
		yyval.symbol_info = new SymbolInfo("", "simple_expression");
		if (yystack.l_mark[-2].symbol_info->get_data_type() == "VOID" || yystack.l_mark[0].symbol_info->get_data_type() == "VOID") {
			show_error(SEMANTIC, VOID_USAGE, "", errorout);
		}
		yyval.symbol_info->set_data_type(type_cast(yystack.l_mark[-2].symbol_info->get_data_type(), yystack.l_mark[0].symbol_info->get_data_type()));
		yyval.symbol_info->set_rule("simple_expression : simple_expression ADDOP term");
		yyval.symbol_info->add_child(yystack.l_mark[-2].symbol_info); yyval.symbol_info->add_child(yystack.l_mark[-1].symbol_info); yyval.symbol_info->add_child(yystack.l_mark[0].symbol_info);
	}
#line 2130 "y.tab.c"
break;
case 57:
#line 692 "parser.y"
	{
		print_grammar_rule("term", "unary_expression");
		yyval.symbol_info = new SymbolInfo(yystack.l_mark[0].symbol_info->get_name(), "term", yystack.l_mark[0].symbol_info->get_data_type());
		yyval.symbol_info->set_array(yystack.l_mark[0].symbol_info->is_array());
		yyval.symbol_info->set_rule("term : unary_expression");
		yyval.symbol_info->add_child(yystack.l_mark[0].symbol_info);
	}
#line 2141 "y.tab.c"
break;
case 58:
#line 699 "parser.y"
	{
		print_grammar_rule("term", "term MULOP unary_expression");
		yyval.symbol_info = new SymbolInfo("", "term");
		if (yystack.l_mark[-2].symbol_info->get_data_type() == "VOID" || yystack.l_mark[0].symbol_info->get_data_type() == "VOID") {
			show_error(SEMANTIC, VOID_USAGE, "", errorout);
			yyval.symbol_info->set_data_type("ERROR");
		}
		else if (yystack.l_mark[-2].symbol_info->get_data_type() == "ERROR" || yystack.l_mark[0].symbol_info->get_data_type() == "ERROR") {
			show_error(SEMANTIC, TYPE_ERROR, "", errorout);
			yyval.symbol_info->set_data_type("ERROR");
		}
		else if (yystack.l_mark[-1].symbol_info->get_name() == "%") {
			if (yystack.l_mark[-2].symbol_info->get_data_type() == "FLOAT" || yystack.l_mark[0].symbol_info->get_data_type() == "FLOAT") {
				show_error(SEMANTIC, MOD_OPERAND, "", errorout);
				yyval.symbol_info->set_data_type("ERROR");
			}
			else if (is_zero(yystack.l_mark[0].symbol_info->get_name())) {
				show_error(WARNING, MOD_BY_ZERO, "", errorout);
				yyval.symbol_info->set_data_type("ERROR");
			}
			else {
				yyval.symbol_info->set_data_type("INT");
			}
		}
		else if (yystack.l_mark[-1].symbol_info->get_name() == "/") {
			if (is_zero(yystack.l_mark[0].symbol_info->get_name())) {
				show_error(WARNING, DIV_BY_ZERO, "", errorout);
				yyval.symbol_info->set_data_type("ERROR");
			}
			else {
				yyval.symbol_info->set_data_type(type_cast(yystack.l_mark[-2].symbol_info->get_data_type(), yystack.l_mark[0].symbol_info->get_data_type()));
			}
		}
		else if (yystack.l_mark[-1].symbol_info->get_name() == "*") {
			yyval.symbol_info->set_data_type(type_cast(yystack.l_mark[-2].symbol_info->get_data_type(), yystack.l_mark[0].symbol_info->get_data_type()));
		}
		yyval.symbol_info->set_rule("term : term MULOP unary_expression");
		yyval.symbol_info->add_child(yystack.l_mark[-2].symbol_info); yyval.symbol_info->add_child(yystack.l_mark[-1].symbol_info); yyval.symbol_info->add_child(yystack.l_mark[0].symbol_info);
	}
#line 2184 "y.tab.c"
break;
case 59:
#line 740 "parser.y"
	{
		print_grammar_rule("unary_expression", "ADDOP unary_expression");
		yyval.symbol_info = new SymbolInfo("", "unary_expression");
		if (yystack.l_mark[0].symbol_info->get_data_type() == "VOID") {
			show_error(SEMANTIC, VOID_USAGE, "", errorout);
			yyval.symbol_info->set_data_type("ERROR");
		}
		else yyval.symbol_info->set_data_type(yystack.l_mark[0].symbol_info->get_data_type());
		yyval.symbol_info->set_rule("unary_expression : ADDOP unary_expression");
		yyval.symbol_info->add_child(yystack.l_mark[-1].symbol_info); yyval.symbol_info->add_child(yystack.l_mark[0].symbol_info);
	}
#line 2199 "y.tab.c"
break;
case 60:
#line 751 "parser.y"
	{
		print_grammar_rule("unary_expression", "ADDOP unary_expression");
		yyval.symbol_info = new SymbolInfo("", "unary_expression");
		bool ok = true;
		if (yystack.l_mark[0].symbol_info->get_data_type() == "VOID") {
			show_error(SEMANTIC, VOID_USAGE, "", errorout);
			yyval.symbol_info->set_data_type("ERROR");
			ok = false;
		}
		else if (yystack.l_mark[0].symbol_info->get_data_type() == "FLOAT") {
			show_error(WARNING, BITWISE_FLOAT, "", errorout);
		}
		if (ok) yyval.symbol_info->set_data_type("INT");
		yyval.symbol_info->set_rule("unary_expression : NOT unary_expression");
		yyval.symbol_info->add_child(yystack.l_mark[-1].symbol_info); yyval.symbol_info->add_child(yystack.l_mark[0].symbol_info);
	}
#line 2219 "y.tab.c"
break;
case 61:
#line 767 "parser.y"
	{
		print_grammar_rule("unary_expression", "factor");
		yyval.symbol_info = new SymbolInfo(yystack.l_mark[0].symbol_info->get_name(), "unary_expression", yystack.l_mark[0].symbol_info->get_data_type());
		yyval.symbol_info->set_array(yystack.l_mark[0].symbol_info->is_array());
		yyval.symbol_info->set_rule("unary_expression : factor");
		yyval.symbol_info->add_child(yystack.l_mark[0].symbol_info);
	}
#line 2230 "y.tab.c"
break;
case 62:
#line 776 "parser.y"
	{
		print_grammar_rule("factor", "variable");
		yyval.symbol_info = new SymbolInfo(yystack.l_mark[0].symbol_info->get_name(), "factor", yystack.l_mark[0].symbol_info->get_data_type());
		yyval.symbol_info->set_array(yystack.l_mark[0].symbol_info->is_array());
		yyval.symbol_info->set_rule("factor : variable");
		yyval.symbol_info->add_child(yystack.l_mark[0].symbol_info);
	}
#line 2241 "y.tab.c"
break;
case 63:
#line 783 "parser.y"
	{
		print_grammar_rule("factor", "ID LPAREN argument_list RPAREN");
		yyval.symbol_info = new SymbolInfo("", "factor");
		SymbolInfo* res = sym->search(yystack.l_mark[-3].symbol_info->get_name(), 'A');
		bool ok = true;
		if (res == nullptr) {
			show_error(SEMANTIC, UNDECLARED_FUNCTION, yystack.l_mark[-3].symbol_info->get_name(), errorout);
			ok = false;
		}
		else if (!res->is_func_declaration() && !res->is_func_definition()) {
			show_error(SEMANTIC, NOT_A_FUNCTION, yystack.l_mark[-3].symbol_info->get_name(), errorout);
			ok = false;
		}
		else if (res->is_func_declaration() && !res->is_func_definition()) {
			show_error(SEMANTIC, UNDEFINED_FUNCTION, yystack.l_mark[-3].symbol_info->get_name(), errorout);
			ok = false;
		}
		else if (res->get_param_list().size() < yystack.l_mark[-1].symbol_info->get_param_list().size()) {
			show_error(SEMANTIC, TOO_MANY_ARGUMENTS, yystack.l_mark[-3].symbol_info->get_name(), errorout);
			ok = false;
		}
		else if (res->get_param_list().size() > yystack.l_mark[-1].symbol_info->get_param_list().size()) {
			show_error(SEMANTIC, TOO_FEW_ARGUMENTS, yystack.l_mark[-3].symbol_info->get_name(), errorout);
			ok = false;
		}
		else {
			vector<Param> now = res->get_param_list();
			vector<Param> they = yystack.l_mark[-1].symbol_info->get_param_list();
			for (int i = 0; i < now.size(); i++) {
				if ((now[i].data_type != they[i].data_type) || (now[i].is_array != they[i].is_array)) {
					/* cerr << "Function: " << res->get_name() << endl;*/
					/* cerr << "original: " << now[i].data_type << " given: " << they[i].data_type << " name: " << now[i].name << " line " << line_count << endl;*/
					string str = to_string(i + 1);
					str += " of \'" + yystack.l_mark[-3].symbol_info->get_name() + "\'";
					show_error(SEMANTIC, ARG_TYPE_MISMATCH, str, errorout);
				}
			}
			yyval.symbol_info->set_data_type(res->get_data_type());
		}
		yyval.symbol_info->set_rule("factor : ID LPAREN argument_list RPAREN");
		yyval.symbol_info->add_child(yystack.l_mark[-3].symbol_info); yyval.symbol_info->add_child(yystack.l_mark[-2].symbol_info); yyval.symbol_info->add_child(yystack.l_mark[-1].symbol_info); yyval.symbol_info->add_child(yystack.l_mark[0].symbol_info);
	}
#line 2287 "y.tab.c"
break;
case 64:
#line 825 "parser.y"
	{
		print_grammar_rule("factor", "LPAREN expression RPAREN");
		yyval.symbol_info = new SymbolInfo(yystack.l_mark[-1].symbol_info->get_name(), "factor", yystack.l_mark[-1].symbol_info->get_data_type());
		yyval.symbol_info->set_rule("factor : LPAREN expression RPAREN");
		yyval.symbol_info->add_child(yystack.l_mark[-2].symbol_info); yyval.symbol_info->add_child(yystack.l_mark[-1].symbol_info); yyval.symbol_info->add_child(yystack.l_mark[0].symbol_info);
	}
#line 2297 "y.tab.c"
break;
case 65:
#line 831 "parser.y"
	{
		print_grammar_rule("factor", "CONST_INT");
		yyval.symbol_info = new SymbolInfo(yystack.l_mark[0].symbol_info->get_name(), "factor", "INT");
		yyval.symbol_info->set_rule("factor : CONST_INT");
		yyval.symbol_info->add_child(yystack.l_mark[0].symbol_info);
	}
#line 2307 "y.tab.c"
break;
case 66:
#line 837 "parser.y"
	{
		print_grammar_rule("factor", "CONST_FLOAT");
		yyval.symbol_info = new SymbolInfo(yystack.l_mark[0].symbol_info->get_name(), "factor", "FLOAT");
		yyval.symbol_info->set_rule("factor : CONST_FLOAT");
		yyval.symbol_info->add_child(yystack.l_mark[0].symbol_info);
	}
#line 2317 "y.tab.c"
break;
case 67:
#line 843 "parser.y"
	{
		print_grammar_rule("factor", "variable INCOP");
		yyval.symbol_info = new SymbolInfo("", "factor");
		if (yystack.l_mark[-1].symbol_info->get_data_type() == "VOID") {
			show_error(SEMANTIC, VOID_USAGE, yystack.l_mark[-1].symbol_info->get_name(), errorout);
			yyval.symbol_info->set_data_type("ERROR");
		}
		else if (yystack.l_mark[-1].symbol_info->get_data_type() == "ERROR") {
			show_error(SEMANTIC, TYPE_ERROR, yystack.l_mark[-1].symbol_info->get_name(), errorout);
			yyval.symbol_info->set_data_type("ERROR");
		}
		else {
			yyval.symbol_info->set_data_type(yystack.l_mark[-1].symbol_info->get_data_type());
		}
		yyval.symbol_info->set_rule("factor : variable INCOP");
		yyval.symbol_info->add_child(yystack.l_mark[-1].symbol_info); yyval.symbol_info->add_child(yystack.l_mark[0].symbol_info);
	}
#line 2338 "y.tab.c"
break;
case 68:
#line 860 "parser.y"
	{
		print_grammar_rule("factor", "variable DECOP");
		yyval.symbol_info = new SymbolInfo("", "factor");
		if (yystack.l_mark[-1].symbol_info->get_data_type() == "VOID") {
			show_error(SEMANTIC, VOID_USAGE, "", errorout);
			yyval.symbol_info->set_data_type("ERROR");
		}
		else if (yystack.l_mark[-1].symbol_info->get_data_type() == "ERROR") {
			show_error(SEMANTIC, TYPE_ERROR, "", errorout);
			yyval.symbol_info->set_data_type("ERROR");
		}
		else {
			yyval.symbol_info->set_data_type(yystack.l_mark[-1].symbol_info->get_data_type());
		}
		yyval.symbol_info->set_rule("factor : variable DECOP");
		yyval.symbol_info->add_child(yystack.l_mark[-1].symbol_info); yyval.symbol_info->add_child(yystack.l_mark[0].symbol_info);
	}
#line 2359 "y.tab.c"
break;
case 69:
#line 879 "parser.y"
	{
		print_grammar_rule("argument_list", "arguments");
		yyval.symbol_info = new SymbolInfo("", "argument_list");
		yyval.symbol_info->set_param_list(yystack.l_mark[0].symbol_info->get_param_list());
		yyval.symbol_info->set_rule("argument_list : arguments");
		yyval.symbol_info->add_child(yystack.l_mark[0].symbol_info);
	}
#line 2370 "y.tab.c"
break;
case 70:
#line 886 "parser.y"
	{
		print_grammar_rule("argument_list", "arguments");
		yyclearin; /* clear the lookahead token*/
		yyerrok; /* start normal parsing again*/
		show_error(SYNTAX, S_ARG_LIST, "", errorout);
		yyval.symbol_info = new SymbolInfo("", "argument_list");
		yyval.symbol_info->set_param_list(yystack.l_mark[-1].symbol_info->get_param_list());
		yyval.symbol_info->set_rule("argument_list : arguments");
		yyval.symbol_info->add_child(yystack.l_mark[-1].symbol_info);
	}
#line 2384 "y.tab.c"
break;
case 71:
#line 896 "parser.y"
	{
		/* empty argument list, as one of the example of the sample suggests*/
		print_grammar_rule("argument_list", "");
		yyval.symbol_info = new SymbolInfo("", "argument_list");
	}
#line 2393 "y.tab.c"
break;
case 72:
#line 903 "parser.y"
	{
		print_grammar_rule("arguments", "arguments COMMA logic_expression");
		yyval.symbol_info = new SymbolInfo("", "arguments");
		yyval.symbol_info->set_param_list(yystack.l_mark[-2].symbol_info->get_param_list());
		yyval.symbol_info->add_param(yystack.l_mark[0].symbol_info->get_name(), yystack.l_mark[0].symbol_info->get_data_type(), yystack.l_mark[0].symbol_info->is_array());
		yyval.symbol_info->set_rule("arguments : arguments COMMA logic_expression");
		yyval.symbol_info->add_child(yystack.l_mark[-2].symbol_info); yyval.symbol_info->add_child(yystack.l_mark[-1].symbol_info); yyval.symbol_info->add_child(yystack.l_mark[0].symbol_info);
	}
#line 2405 "y.tab.c"
break;
case 73:
#line 911 "parser.y"
	{
		print_grammar_rule("arguments", "logic_expression");
		yyval.symbol_info = new SymbolInfo("", "arguments");
		yyval.symbol_info->add_param(yystack.l_mark[0].symbol_info->get_name(), yystack.l_mark[0].symbol_info->get_data_type(), yystack.l_mark[0].symbol_info->is_array());
		yyval.symbol_info->set_rule("arguments : logic_expression");
		yyval.symbol_info->add_child(yystack.l_mark[0].symbol_info);
	}
#line 2416 "y.tab.c"
break;
case 74:
#line 920 "parser.y"
	{
		yyval.symbol_info = new SymbolInfo("", "LCURLS");
		sym->enter_scope();
		/* why am I inserting symbols here? so that the parameters can be recognized in the newly created scope*/
		/* but remember, in case of function prototypes, even though I am not inserting the symbols, I am still checking in */
		/* insert_function() whether two non-empty names are same or not*/
		for (const Param& they : current_function_parameters) {
			if (they.name == "") {/* nameless, no need to insert */
				show_error(SYNTAX, S_PARAM_NAMELESS, "", errorout);
				continue;
			}
			SymbolInfo* another = new SymbolInfo(they.name, "ID", they.data_type);
			another->set_array(they.is_array);
			if (!sym->insert(another)) {
				/* insertion failed*/
				show_error(SEMANTIC, PARAM_REDEFINITION, another->get_name(), errorout);
				/* in sample output, after any failure, the next arguments are not inserted to the symbol table*/
				/* so we will break the loop*/
				delete another;
				break;
			}
		}
		reset_current_parameters();
		yyval.symbol_info->set_rule("");
		yyval.symbol_info->add_child(yystack.l_mark[0].symbol_info);
	}
#line 2446 "y.tab.c"
break;
#line 2448 "y.tab.c"
    default:
        break;
    }
    yystack.s_mark -= yym;
    yystate = *yystack.s_mark;
    yystack.l_mark -= yym;
#if defined(YYLTYPE) || defined(YYLTYPE_IS_DECLARED)
    yystack.p_mark -= yym;
#endif
    yym = yylhs[yyn];
    if (yystate == 0 && yym == 0)
    {
#if YYDEBUG
        if (yydebug)
        {
            fprintf(stderr, "%s[%d]: after reduction, ", YYDEBUGSTR, yydepth);
#ifdef YYSTYPE_TOSTRING
#if YYBTYACC
            if (!yytrial)
#endif /* YYBTYACC */
                fprintf(stderr, "result is <%s>, ", YYSTYPE_TOSTRING(yystos[YYFINAL], yyval));
#endif
            fprintf(stderr, "shifting from state 0 to final state %d\n", YYFINAL);
        }
#endif
        yystate = YYFINAL;
        *++yystack.s_mark = YYFINAL;
        *++yystack.l_mark = yyval;
#if defined(YYLTYPE) || defined(YYLTYPE_IS_DECLARED)
        *++yystack.p_mark = yyloc;
#endif
        if (yychar < 0)
        {
#if YYBTYACC
            do {
            if (yylvp < yylve)
            {
                /* we're currently re-reading tokens */
                yylval = *yylvp++;
#if defined(YYLTYPE) || defined(YYLTYPE_IS_DECLARED)
                yylloc = *yylpp++;
#endif
                yychar = *yylexp++;
                break;
            }
            if (yyps->save)
            {
                /* in trial mode; save scanner results for future parse attempts */
                if (yylvp == yylvlim)
                {   /* Enlarge lexical value queue */
                    size_t p = (size_t) (yylvp - yylvals);
                    size_t s = (size_t) (yylvlim - yylvals);

                    s += YYLVQUEUEGROWTH;
                    if ((yylexemes = (YYINT *)realloc(yylexemes, s * sizeof(YYINT))) == NULL)
                        goto yyenomem;
                    if ((yylvals   = (YYSTYPE *)realloc(yylvals, s * sizeof(YYSTYPE))) == NULL)
                        goto yyenomem;
#if defined(YYLTYPE) || defined(YYLTYPE_IS_DECLARED)
                    if ((yylpsns   = (YYLTYPE *)realloc(yylpsns, s * sizeof(YYLTYPE))) == NULL)
                        goto yyenomem;
#endif
                    yylvp   = yylve = yylvals + p;
                    yylvlim = yylvals + s;
#if defined(YYLTYPE) || defined(YYLTYPE_IS_DECLARED)
                    yylpp   = yylpe = yylpsns + p;
                    yylplim = yylpsns + s;
#endif
                    yylexp  = yylexemes + p;
                }
                *yylexp = (YYINT) YYLEX;
                *yylvp++ = yylval;
                yylve++;
#if defined(YYLTYPE) || defined(YYLTYPE_IS_DECLARED)
                *yylpp++ = yylloc;
                yylpe++;
#endif
                yychar = *yylexp++;
                break;
            }
            /* normal operation, no conflict encountered */
#endif /* YYBTYACC */
            yychar = YYLEX;
#if YYBTYACC
            } while (0);
#endif /* YYBTYACC */
            if (yychar < 0) yychar = YYEOF;
#if YYDEBUG
            if (yydebug)
            {
                if ((yys = yyname[YYTRANSLATE(yychar)]) == NULL) yys = yyname[YYUNDFTOKEN];
                fprintf(stderr, "%s[%d]: state %d, reading token %d (%s)\n",
                                YYDEBUGSTR, yydepth, YYFINAL, yychar, yys);
            }
#endif
        }
        if (yychar == YYEOF) goto yyaccept;
        goto yyloop;
    }
    if (((yyn = yygindex[yym]) != 0) && (yyn += yystate) >= 0 &&
            yyn <= YYTABLESIZE && yycheck[yyn] == (YYINT) yystate)
        yystate = yytable[yyn];
    else
        yystate = yydgoto[yym];
#if YYDEBUG
    if (yydebug)
    {
        fprintf(stderr, "%s[%d]: after reduction, ", YYDEBUGSTR, yydepth);
#ifdef YYSTYPE_TOSTRING
#if YYBTYACC
        if (!yytrial)
#endif /* YYBTYACC */
            fprintf(stderr, "result is <%s>, ", YYSTYPE_TOSTRING(yystos[yystate], yyval));
#endif
        fprintf(stderr, "shifting from state %d to state %d\n", *yystack.s_mark, yystate);
    }
#endif
    if (yystack.s_mark >= yystack.s_last && yygrowstack(&yystack) == YYENOMEM) goto yyoverflow;
    *++yystack.s_mark = (YYINT) yystate;
    *++yystack.l_mark = yyval;
#if defined(YYLTYPE) || defined(YYLTYPE_IS_DECLARED)
    *++yystack.p_mark = yyloc;
#endif
    goto yyloop;
#if YYBTYACC

    /* Reduction declares that this path is valid. Set yypath and do a full parse */
yyvalid:
    if (yypath) YYABORT;
    while (yyps->save)
    {
        YYParseState *save = yyps->save;
        yyps->save = save->save;
        save->save = yypath;
        yypath = save;
    }
#if YYDEBUG
    if (yydebug)
        fprintf(stderr, "%s[%d]: state %d, CONFLICT trial successful, backtracking to state %d, %d tokens\n",
                        YYDEBUGSTR, yydepth, yystate, yypath->state, (int)(yylvp - yylvals - yypath->lexeme));
#endif
    if (yyerrctx)
    {
        yyFreeState(yyerrctx);
        yyerrctx = NULL;
    }
    yylvp          = yylvals + yypath->lexeme;
#if defined(YYLTYPE) || defined(YYLTYPE_IS_DECLARED)
    yylpp          = yylpsns + yypath->lexeme;
#endif
    yylexp         = yylexemes + yypath->lexeme;
    yychar         = YYEMPTY;
    yystack.s_mark = yystack.s_base + (yypath->yystack.s_mark - yypath->yystack.s_base);
    memcpy (yystack.s_base, yypath->yystack.s_base, (size_t) (yystack.s_mark - yystack.s_base + 1) * sizeof(YYINT));
    yystack.l_mark = yystack.l_base + (yypath->yystack.l_mark - yypath->yystack.l_base);
    memcpy (yystack.l_base, yypath->yystack.l_base, (size_t) (yystack.l_mark - yystack.l_base + 1) * sizeof(YYSTYPE));
#if defined(YYLTYPE) || defined(YYLTYPE_IS_DECLARED)
    yystack.p_mark = yystack.p_base + (yypath->yystack.p_mark - yypath->yystack.p_base);
    memcpy (yystack.p_base, yypath->yystack.p_base, (size_t) (yystack.p_mark - yystack.p_base + 1) * sizeof(YYLTYPE));
#endif
    yystate        = yypath->state;
    goto yyloop;
#endif /* YYBTYACC */

yyoverflow:
    YYERROR_CALL("yacc stack overflow");
#if YYBTYACC
    goto yyabort_nomem;
yyenomem:
    YYERROR_CALL("memory exhausted");
yyabort_nomem:
#endif /* YYBTYACC */
    yyresult = 2;
    goto yyreturn;

yyabort:
    yyresult = 1;
    goto yyreturn;

yyaccept:
#if YYBTYACC
    if (yyps->save) goto yyvalid;
#endif /* YYBTYACC */
    yyresult = 0;

yyreturn:
#if defined(YYDESTRUCT_CALL)
    if (yychar != YYEOF && yychar != YYEMPTY)
#if defined(YYLTYPE) || defined(YYLTYPE_IS_DECLARED)
        YYDESTRUCT_CALL("cleanup: discarding token", yychar, &yylval, &yylloc);
#else
        YYDESTRUCT_CALL("cleanup: discarding token", yychar, &yylval);
#endif /* defined(YYLTYPE) || defined(YYLTYPE_IS_DECLARED) */

    {
        YYSTYPE *pv;
#if defined(YYLTYPE) || defined(YYLTYPE_IS_DECLARED)
        YYLTYPE *pp;

        for (pv = yystack.l_base, pp = yystack.p_base; pv <= yystack.l_mark; ++pv, ++pp)
             YYDESTRUCT_CALL("cleanup: discarding state",
                             yystos[*(yystack.s_base + (pv - yystack.l_base))], pv, pp);
#else
        for (pv = yystack.l_base; pv <= yystack.l_mark; ++pv)
             YYDESTRUCT_CALL("cleanup: discarding state",
                             yystos[*(yystack.s_base + (pv - yystack.l_base))], pv);
#endif /* defined(YYLTYPE) || defined(YYLTYPE_IS_DECLARED) */
    }
#endif /* defined(YYDESTRUCT_CALL) */

#if YYBTYACC
    if (yyerrctx)
    {
        yyFreeState(yyerrctx);
        yyerrctx = NULL;
    }
    while (yyps)
    {
        YYParseState *save = yyps;
        yyps = save->save;
        save->save = NULL;
        yyFreeState(save);
    }
    while (yypath)
    {
        YYParseState *save = yypath;
        yypath = save->save;
        save->save = NULL;
        yyFreeState(save);
    }
#endif /* YYBTYACC */
    yyfreestack(&yystack);
    return (yyresult);
}
