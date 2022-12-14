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

string cur_string;

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

%}

WHITESPACE [ \t\f\r\v]+
LETTER [_a-zA-Z]
DIGIT [0-9]
NEWLINE \n
ALPHANUMERIC ({LETTER}|{DIGIT})*
FLOAT_DECIMAL ({DIGIT}*\.{DIGIT}+([Ee][-+]?{DIGIT}+)?)|({DIGIT}+[Ee][-+]?{DIGIT}+)

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
		

{DIGIT}+ 			{
						tokenout << "<CONST_INT, " << yytext << ">" << endl;
						logout << "Line# " << line_count << ": Token <CONST_INT> Lexeme " << yytext << " found" << endl;
					}
			
{FLOAT_DECIMAL}		{
						tokenout << "<CONST_FLOAT, " << yytext << ">" << endl;
						logout << "Line# " << line_count << ": Token <CONST_FLOAT> Lexeme " << yytext << " found" << endl;
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
						BEGIN STATE_CHAR;
					}

<STATE_CHAR>\\\'	{ cur_string += "\'"; }
<STATE_CHAR>\\\"	{ cur_string += "\""; }
<STATE_CHAR>\\n		{ cur_string += "\n"; }
<STATE_CHAR>\\t		{ cur_string += "\t"; }
<STATE_CHAR>\\\\	{ cur_string += "\\"; }
<STATE_CHAR>\\a		{ cur_string += "\a"; }
<STATE_CHAR>\\f		{ cur_string += "\f"; }
<STATE_CHAR>\\r		{ cur_string += "\r"; }
<STATE_CHAR>\\b		{ cur_string += "\b"; }
<STATE_CHAR>\\v		{ cur_string += "\v"; }
<STATE_CHAR>\\0		{ cur_string += "\0"; }
<STATE_CHAR>\'		{ 
						tokenout << "<CONST_CHAR, " << cur_string << ">" << endl;
						logout << "Line# " << line_count << ": Token <CONST_CHAR> Lexeme " << cur_string << " found" << endl;
						BEGIN INITIAL;
					}

. 					{}

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
