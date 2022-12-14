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

string cur_char;

SymbolTable sym(BUCKET_SIZE);

string capitalize(const string& s) {
	string ret = s;
	for (char& c : ret) c = toupper(c);
	return ret;
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
						tokenout << "<" << capitalize(yytext) << ", " << yytext << endl;
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

\'					{
						cur_char.clear();
						BEGIN STATE_CHAR;
					}

<STATE_CHAR>\\\'	{ cur_char += "\'"; }
<STATE_CHAR>\\\"	{ cur_char += "\""; }
<STATE_CHAR>\\n		{ cur_char += "\n"; }
<STATE_CHAR>\\t		{ cur_char += "\t"; }
<STATE_CHAR>\\\\	{ cur_char += "\\"; }
<STATE_CHAR>\\a		{ cur_char += "\a"; }
<STATE_CHAR>\\f		{ cur_char += "\f"; }
<STATE_CHAR>\\r		{ cur_char += "\r"; }
<STATE_CHAR>\\b		{ cur_char += "\b"; }
<STATE_CHAR>\\v		{ cur_char += "\v"; }
<STATE_CHAR>\\0		{ cur_char += "\0"; }
<STATE_CHAR>\'		{ 
						tokenout << "<CONST_CHAR, " << cur_char << ">" << endl;
						logout << "Line# " << line_count << ": Token <CONST_CHAR> Lexeme " << cur_char << " found" << endl;
						BEGIN INITIAL;
					}

. 					{}

%%

int main(int argc, char** argv) {
	if(argc!=2){
		printf("Please provide input file name and try again\n");
		return 0;
	}
	
	FILE *fin=fopen(argv[1],"r");
	if(fin==NULL){
		printf("Cannot open specified file\n");
		return 0;
	}
	
	logout.open("1905001_log.txt");
	tokenout.open("1905001_token.txt");

	yyin= fin;
	yylex();
	// st.print();
	fclose(yyin);
	tokenout.close();
	logout.close();
	return 0;
}
