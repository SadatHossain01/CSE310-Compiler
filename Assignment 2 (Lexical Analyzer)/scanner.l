%option noyywrap

%x STATE_CHAR
%x STATE_STRING

%{
	
#include<cstdio>
#include<cstdlib>
#include<vector>
#include "symbol_table.h"

using namespace std;

#define BUCKET_SIZE 10

int line_count = 1;
int error_count = 0;

ofstream logout;
ofstream tokenout;

int char_len, str_len;
// if a string stretches multiple lines, we need to show the starting line no, 
// hence needs to keep the line no. unchanged while the string is on.
int inside_line = 0; 
string cur_char, cur_string;

enum error_type {
	MULTICHAR, EMPTY_CHAR, UNFINISHED_CHAR, UNRECOGNIZED, TOO_DECIMAL, 
	ILL_FORMED, INVALID_SUFFIX, UNFINISHED_STRING};
enum num_type {INTEGER, FLOAT};
enum string_type {SINGLE_LINE, MULTILINE};

SymbolTable sym(BUCKET_SIZE);

string capitalize(const string& s) {
	string ret = s;
	for (char& c : ret) c = toupper(c);
	return ret;
}

void printKeyword() {
	string cap = capitalize(yytext);
	tokenout << "<" << cap << ", " << yytext << ">" << endl;
	logout << "Line# " << line_count << ": Token <" << cap << "> Lexeme " << yytext << " found" << endl;
}

void printNum(num_type nt) {
	if (nt == INTEGER) {
		tokenout << "<CONST_INT, " << yytext << ">" << endl;
		logout << "Line# " << line_count << ": Token <CONST_INT> Lexeme " << yytext << " found" << endl;
	}
	else if (nt == FLOAT) {
		tokenout << "<CONST_FLOAT, " << yytext << ">" << endl;
		logout << "Line# " << line_count << ": Token <CONST_FLOAT> Lexeme " << yytext << " found" << endl;
	}
}

void printOpPunc(const string& token) {
	tokenout << "<" << token << ", " << yytext << ">" << endl;
	logout << "Line# " << line_count << ": Token <" << token << "> Lexeme " << yytext << " found" << endl;	
}

void printChar() {
	tokenout << "<CONST_CHAR, " << cur_char << ">" << endl;
	logout << "Line# " << line_count << ": Token <CONST_CHAR> Lexeme " << cur_char << " found" << endl;
}

void printString(string_type st, const string& str) {
	if (st == SINGLE_LINE) {
		logout << "Line# " << line_count << ": Token <SINGLE LINE STRING> Lexeme " << str << " found" << endl;
	}
	else if (st == MULTILINE) {
		logout << "Line# " << line_count << ": Token <MULTI LINE STRING> Lexeme " << str << " found" << endl;
	}
}

void show_error(error_type e, const string& str) {
	error_count++;

	logout << "Error at line# " << line_count << ": ";
	
	if (e == MULTICHAR) {
		logout << "MULTICHAR_CONST_CHAR " << str << endl;
	}
	else if (e == EMPTY_CHAR) {
		logout << "EMPTY_CONST_CHAR " << str << endl;
	}
	else if (e == UNFINISHED_CHAR) {
		logout << "UNFINISHED_CONST_CHAR " << str << endl;
	}
	else if (e == UNRECOGNIZED) {
		logout << "UNRECOGNIZED_CHAR " << str << endl;
	}
	else if (e == TOO_DECIMAL) {
		logout << "TOO MANY DECIMAL POINTS " << str << endl;
	}
	else if (e == ILL_FORMED) {
		logout << "ILLFORMED_NUMBER " << str << endl;
	}
	else if (e == INVALID_SUFFIX) {
		logout << "INVALID_ID_SUFFIX_NUM_PREFIX " << str << endl;
	}
	else if (e == UNFINISHED_STRING) {
		logout << "UNFINISHED_STRING " << str << endl;
	}
}

%}

WHITESPACE [ \t\f\r\v]+
LETTER [a-zA-Z]
DIGIT [0-9]
NEWLINE \r?\n
ALPHABET {LETTER}|_
ALPHANUMERIC {ALPHABET}|{DIGIT}

IDENTIFIER {ALPHABET}{ALPHANUMERIC}*
NON_IDENTIFIER {DIGIT}{ALPHANUMERIC}*

FRACTION (\.{DIGIT}+)

INTEGER {DIGIT}+
FLOATING_POINT (({INTEGER}{FRACTION}?)|{FRACTION})([Ee][-+]?{INTEGER})?
TOO_DECIMAL ({DIGIT}*(\.{DIGIT}*)\.[-+0-9\.Ee]*)
ILL_FORMED ({INTEGER}|{FLOATING_POINT})[eE]*{FLOATING_POINT}*

%%

{WHITESPACE} 		{}
{NEWLINE} 			{ line_count++; }

"if"				|
"else"				|
"for"				|
"while"				|
"do"				|
"break"				|
"int"				|
"char"				|
"float"				|
"double"			|
"void"				|
"return"			|
"switch"			|
"case"				|
"default"			|
"continue"			{ printKeyword(); }
		

{INTEGER} 			{ printNum(INTEGER); }
{FLOATING_POINT}	{ printNum(FLOAT); }
{TOO_DECIMAL}		{ show_error(TOO_DECIMAL, yytext); }					
{ILL_FORMED}		{ show_error(ILL_FORMED, yytext); }
{IDENTIFIER} 		{
						logout << "Line# " << line_count << ": Token <ID> Lexeme " << yytext << " found" << endl;
						tokenout << "<ID, " << yytext << ">" << endl;
						bool success = sym.insert(yytext, "ID", logout);
						if (success) sym.print('A', logout);
					}
{NON_IDENTIFIER} 	{ show_error(INVALID_SUFFIX, yytext); }


"+"					|
"-"					{ printOpPunc("ADDOP"); }
"*"					|
"/"					|
"%"					{ printOpPunc("MULOP"); }
"++"				|
"--"				{ printOpPunc("INCOP"); }
"<"					|
"<="				|
">"					|
">="				|
"=="				|
"!="				{ printOpPunc("RELOP"); }
"="					{ printOpPunc("ASSIGNOP"); }
"&&"				|
"||"				{ printOpPunc("LOGICOP"); }
"&"					|
"|"					|
"^"					|
"<<"				|
">>"				{ printOpPunc("BITOP"); }
"!"					{ printOpPunc("NOT"); }
"("					{ printOpPunc("LPAREN"); }
")"					{ printOpPunc("RPAREN"); }
"{"					{ printOpPunc("LCURL"); sym.enter_scope(); }
"}"					{ printOpPunc("RCURL"); sym.exit_scope(); }
"["					{ printOpPunc("LSQUARE"); }
"]"					{ printOpPunc("RSQUARE"); }
","					{ printOpPunc("COMMA"); }
";"					{ printOpPunc("SEMICOLON"); }


\'					{
						cur_char.clear();
						char_len = 0;
						BEGIN STATE_CHAR;
					}
\"					{
						cur_string.clear();
						str_len = 0;
						inside_line = 0;
						BEGIN STATE_STRING;
					}

<STATE_CHAR>\\\'	{ cur_char += "\'"; char_len++; }
<STATE_CHAR>\\\"	{ cur_char += "\""; char_len++; }
<STATE_CHAR>\\n		{ cur_char += "\n"; char_len++; }
<STATE_CHAR>\\t		{ cur_char += "\t"; char_len++; }
<STATE_CHAR>\\\\	{ cur_char += "\\"; char_len++; }
<STATE_CHAR>\\a		{ cur_char += "\a"; char_len++; }
<STATE_CHAR>\\f		{ cur_char += "\f"; char_len++; }
<STATE_CHAR>\\r		{ cur_char += "\r"; char_len++; }
<STATE_CHAR>\\b		{ cur_char += "\b"; char_len++; }
<STATE_CHAR>\\v		{ cur_char += "\v"; char_len++; }
<STATE_CHAR>\\0		{ cur_char += "\0"; char_len++; }
<STATE_CHAR><<EOF>>	{
						string str = "\'" + cur_char;
						show_error(UNFINISHED_CHAR, str);
						char_len = 0;
						cur_char.clear();
						BEGIN INITIAL;
					}
<STATE_CHAR>\'		{	 	
						if (char_len == 0) {
							string str = "\'\'";
							show_error(EMPTY_CHAR, str);
						}
						else if (char_len > 1) {
							string str = "\'" + cur_char + "\'";
							show_error(MULTICHAR, str);
						}
						else printChar();
						BEGIN INITIAL;
						char_len = 0;
						cur_char.clear();
					}
<STATE_CHAR>{NEWLINE} { 
						string str = "\'" + cur_char;
						show_error(UNFINISHED_CHAR, str); 
						line_count++;
						BEGIN INITIAL;
						char_len = 0;
						cur_char.clear();
					  }
<STATE_CHAR>.		{ cur_char += yytext[0]; char_len++; }


<STATE_STRING>\\\'	{ cur_string += "\'"; str_len++; }
<STATE_STRING>\\\"	{ cur_string += "\""; str_len++; }
<STATE_STRING>\\t	{ cur_string += "\t"; str_len++; }
<STATE_STRING>\\n	{ cur_string += "\n"; str_len++; }
<STATE_STRING>\\\\	{ cur_string += "\\"; str_len++; }
<STATE_STRING>\\a	{ cur_string += "\a"; str_len++; }
<STATE_STRING>\\f	{ cur_string += "\f"; str_len++; }
<STATE_STRING>\\r	{ cur_string += "\r"; str_len++; }
<STATE_STRING>\\b	{ cur_string += "\b"; str_len++; }
<STATE_STRING>\\v	{ cur_string += "\v"; str_len++; }
<STATE_STRING>\\0	{ cur_string += "\0"; str_len++; }
<STATE_STRING>\\\n 	{ inside_line++; cur_string += "\n"; str_len++; }
<STATE_STRING>\\\r\n { inside_line++; cur_string += "\r\n"; str_len++; }
<STATE_STRING>{NEWLINE} {
							// error as multiline string must have '\' at the end of a line
							inside_line++;
							string str = "\"" + cur_string;
							show_error(UNFINISHED_STRING, str);
							line_count += inside_line;
							BEGIN INITIAL;
						}
<STATE_STRING><<EOF>> 	{
							string str = "\"" + cur_string;
							show_error(UNFINISHED_STRING, str);
							line_count += inside_line;
							BEGIN INITIAL;
						}
<STATE_STRING>\"	{
						string str = "\"" + cur_string + "\"";
						if (inside_line == 0) printString(SINGLE_LINE, str);
						else printString(MULTILINE, str);
						line_count += inside_line;
						BEGIN INITIAL;
					}
<STATE_STRING>.		{ cur_string += yytext[0]; str_len++; }


. 					{ show_error(UNRECOGNIZED, yytext); }

%%

int main(int argc, char** argv) {
	if(argc != 2){
		printf("Please provide input file name and try again\n");
		return 0;
	}
	
	FILE *fin=fopen(argv[1], "r");
	if(fin == NULL){
		printf("Cannot open specified file\n");
		return 0;
	}
	
	logout.open("1905001_log.txt");
	tokenout.open("1905001_token.txt");

	yyin = fin;
	yylex();
	fclose(yyin);
	logout << "Total lines: " << line_count << endl;
	logout << "Total errors: " << error_count << endl;
	tokenout.close();
	logout.close();
	return 0;
}
