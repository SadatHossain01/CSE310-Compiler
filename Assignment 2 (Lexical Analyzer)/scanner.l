%option noyywrap

%x STATE_CHAR
%x STATE_STRING
%x STATE_S_COMMENT
%x STATE_D_COMMENT

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

// if a string stretches multiple lines, we need to show the starting line no, 
// hence needs to keep the line no. unchanged while the string is on.
int inside_line = 0; 

// in case of printing char, comment, strings, if it is unfinished then we print
// characters like \n \b as they are (not their original behaviour), but if they are 
// completed properly, then \n will be replaced by newline...

string cur_char, cur_char_raw;
string cur_string, cur_string_raw;
string cur_comment, cur_comment_raw;
int char_len, str_len, comment_len; // will hold the length of the original one, not raw one

enum error_type {
	MULTICHAR, EMPTY_CHAR, UNFINISHED_CHAR, UNRECOGNIZED, TOO_DECIMAL, 
	ILL_FORMED, INVALID_SUFFIX, UNFINISHED_STRING};
enum num_type {INTEGER, FLOAT};
enum string_type {SINGLE_LINE, MULTILINE};
enum reset_type {CHAR, STRING, COMMENT};

SymbolTable sym(BUCKET_SIZE);

void reset(reset_type rt) {
	if (rt == CHAR) {
		cur_char.clear();
		cur_char_raw.clear();
		char_len = 0;
	}
	else if (rt == STRING) {
		cur_string.clear();
		cur_string_raw.clear();
		str_len = 0;
	}
	else if (rt == COMMENT) {
		cur_comment.clear();
		cur_comment_raw.clear();
		comment_len = 0;
	}
}

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

void printChar(const string& str) {
	tokenout << "<CONST_CHAR, " << str << ">" << endl;
	logout << "Line# " << line_count << ": Token <CONST_CHAR> Lexeme " << str << " found" << endl;
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
\/\/				{
						cur_comment.clear();
						comment_len = 0;
						inside_line = 0;
						BEGIN STATE_S_COMMENT;
					}
\/\*				{
						cur_comment.clear();
						comment_len = 0;
						inside_line = 0;
						BEGIN STATE_D_COMMENT;
					}


<STATE_CHAR>\\\'	{ cur_char += "\'"; cur_char_raw += "\\\'"; char_len++; }
<STATE_CHAR>\\\"	{ cur_char += "\""; cur_char_raw += "\\\""; char_len++; }
<STATE_CHAR>\\n		{ cur_char += "\n"; cur_char_raw += "\\n"; char_len++; }
<STATE_CHAR>\\t		{ cur_char += "\t"; cur_char_raw += "\\t"; char_len++; }
<STATE_CHAR>\\\\	{ cur_char += "\\"; cur_char_raw += "\\\\"; char_len++; }
<STATE_CHAR>\\a		{ cur_char += "\a"; cur_char_raw += "\\a"; char_len++; }
<STATE_CHAR>\\f		{ cur_char += "\f"; cur_char_raw += "\\f"; char_len++; }
<STATE_CHAR>\\r		{ cur_char += "\r"; cur_char_raw += "\\r"; char_len++; }
<STATE_CHAR>\\b		{ cur_char += "\b"; cur_char_raw += "\\b"; char_len++; }
<STATE_CHAR>\\v		{ cur_char += "\v"; cur_char_raw += "\\v"; char_len++; }
<STATE_CHAR>\\0		{ cur_char += "\0"; cur_char_raw += "\\0"; char_len++; }
<STATE_CHAR><<EOF>>	{
						string str = "\'" + cur_char_raw;
						show_error(UNFINISHED_CHAR, str);
						BEGIN INITIAL;
						reset(CHAR);
					}
<STATE_CHAR>\'		{	 	
						if (char_len == 0) {
							string str = "\'\'";
							show_error(EMPTY_CHAR, str);
						}
						else if (char_len > 1) {
							// review this line later
							string str = "\'" + cur_char + "\'";
							show_error(MULTICHAR, str);
						}
						else printChar(cur_char);
						BEGIN INITIAL;
						reset(CHAR);
					}
<STATE_CHAR>{NEWLINE} { 
						string str = "\'" + cur_char_raw;
						show_error(UNFINISHED_CHAR, str); 
						line_count++;
						BEGIN INITIAL;
						reset(CHAR);
					  }
<STATE_CHAR>.		{ cur_char += yytext[0]; cur_char_raw += yytext[0]; char_len++; }


<STATE_STRING>\\\'	{ cur_string += "\'"; cur_string_raw += "\\\'"; str_len++; }
<STATE_STRING>\\\"	{ cur_string += "\""; cur_string_raw += "\\\""; str_len++; }
<STATE_STRING>\\t	{ cur_string += "\t"; cur_string_raw += "\\t"; str_len++; }
<STATE_STRING>\\n	{ cur_string += "\n"; cur_string_raw += "\\n"; str_len++; }
<STATE_STRING>\\\\	{ cur_string += "\\"; cur_string_raw += "\\\\"; str_len++; }
<STATE_STRING>\\a	{ cur_string += "\a"; cur_string_raw += "\\a"; str_len++; }
<STATE_STRING>\\f	{ cur_string += "\f"; cur_string_raw += "\\f"; str_len++; }
<STATE_STRING>\\r	{ cur_string += "\r"; cur_string_raw += "\\r"; str_len++; }
<STATE_STRING>\\b	{ cur_string += "\b"; cur_string_raw += "\\b"; str_len++; }
<STATE_STRING>\\v	{ cur_string += "\v"; cur_string_raw += "\\v"; str_len++; }
<STATE_STRING>\\0	{ cur_string += "\0"; cur_string_raw += "\\0"; str_len++; }
<STATE_STRING>\\\n 	{ 
						// an example comment like this: "abc\
						def"
						inside_line++; 
						cur_string += "\n";  
						cur_string_raw += "\\\n";
						str_len++; 
					}
<STATE_STRING>\\\r\n 	{ 
							// similar to previous one
							inside_line++; 
							cur_string += "\r\n"; 
							cur_string_raw += "\\\r\n";
							str_len++; 
						}
<STATE_STRING>{NEWLINE} {
							// error as multiline string must have '\' at the end of a line
							inside_line++;
							string str = "\"" + cur_string_raw;
							show_error(UNFINISHED_STRING, str);
							line_count += inside_line;
							BEGIN INITIAL;
							reset(STRING);
						}
<STATE_STRING><<EOF>> 	{
							string str = "\"" + cur_string_raw;
							show_error(UNFINISHED_STRING, str);
							line_count += inside_line;
							BEGIN INITIAL;
							reset(STRING);
						}
<STATE_STRING>\"	{
						string str = "\"" + cur_string_raw + "\"";
						if (inside_line == 0) printString(SINGLE_LINE, str);
						else printString(MULTILINE, str);
						line_count += inside_line;
						BEGIN INITIAL;
						reset(STRING);
					}
<STATE_STRING>.		{ cur_string += yytext[0]; cur_string_raw += yytext[0]; str_len++; }

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
