%option noyywrap

%x STATE_CHAR

%{
	
#include<cstdio>
#include<cstdlib>
#include<string>
#include<vector>
#include "symbol_table.h"

using namespace std;

#define BUCKET_SIZE 10

int line_count = 1;
int error_count = 0;

ofstream logout;
ofstream tokenout;

int cur_len;
string cur_string;

enum error_type {MULTICHAR, UNFINISHED_CHAR, UNRECOGNIZED, TOO_DECIMAL};

SymbolTable sym(BUCKET_SIZE);

string capitalize(const string& s) {
	string ret = s;
	for (char& c : ret) c = toupper(c);
	return ret;
}

void printOpPunc(const string& token) {
	tokenout << "<" << token << ", " << yytext << ">" << endl;
	logout << "Line# " << line_count << ": Token <" << token << "> Lexeme " << yytext << " found" << endl;	
}

void show_error(error_type e, const string& str) {
	error_count++;

	logout << "Error at line# " << line_count << ": ";
	
	if (e == MULTICHAR) {
		logout << "MULTICHAR_CONST_CHAR " << str << endl;
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
"continue"			{
						tokenout << "<" << capitalize(yytext) << ", " << yytext << ">" << endl;
						logout << "Line# " << line_count << ": Token <" << capitalize(yytext) << "> Lexeme " << yytext << " found" << endl;
					}
		

{INTEGER} 			{
						tokenout << "<CONST_INT, " << yytext << ">" << endl;
						logout << "Line# " << line_count << ": Token <CONST_INT> Lexeme " << yytext << " found" << endl;
					}
			
{FLOATING_POINT}	{
						tokenout << "<CONST_FLOAT, " << yytext << ">" << endl;
						logout << "Line# " << line_count << ": Token <CONST_FLOAT> Lexeme " << yytext << " found" << endl;
					}

{TOO_DECIMAL}		{
						show_error(TOO_DECIMAL, yytext);
					}					

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
"{"					{ printOpPunc("LCURL"); }
"}"					{ printOpPunc("RCURL"); }
"["					{ printOpPunc("LSQUARE"); }
"]"					{ printOpPunc("RSQUARE"); }
","					{ printOpPunc("COMMA"); }
";"					{ printOpPunc("SEMICOLON"); }


\'					{
						cur_string.clear();
						cur_len = 0;
						BEGIN STATE_CHAR;
					}

<STATE_CHAR>\\\'	{ cur_string += "\'"; cur_len++; }
<STATE_CHAR>\\\"	{ cur_string += "\""; cur_len++; }
<STATE_CHAR>\\n		{ cur_string += "\n"; cur_len++; }
<STATE_CHAR>\\t		{ cur_string += "\t"; cur_len++; }
<STATE_CHAR>\\\\	{ cur_string += "\\"; cur_len++; }
<STATE_CHAR>\\a		{ cur_string += "\a"; cur_len++; }
<STATE_CHAR>\\f		{ cur_string += "\f"; cur_len++; }
<STATE_CHAR>\\r		{ cur_string += "\r"; cur_len++; }
<STATE_CHAR>\\b		{ cur_string += "\b"; cur_len++; }
<STATE_CHAR>\\v		{ cur_string += "\v"; cur_len++; }
<STATE_CHAR>\\0		{ cur_string += "\0"; cur_len++; }
<STATE_CHAR>\'		{ 
						if (cur_len == 0) {
							string str = "\'\'";
							show_error(MULTICHAR, str);
						}
						else if (cur_len > 1) {
							string str = "\'" + cur_string + "\'";
							show_error(MULTICHAR, str);
						}
						else {
							tokenout << "<CONST_CHAR, " << cur_string << ">" << endl;
							logout << "Line# " << line_count << ": Token <CONST_CHAR> Lexeme " << cur_string << " found" << endl;
						}
						BEGIN INITIAL;
					}
<STATE_CHAR><<EOF>>	{
						string str = "\'" + cur_string;
						show_error(UNFINISHED_CHAR, str);
						BEGIN INITIAL;
					}

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
	tokenout.close();
	logout.close();
	return 0;
}
