%option noyywrap

%x STATE_CHAR
%x STATE_STRING
%x STATE_S_COMMENT
%x STATE_STAR_COMMENT

%{
	
#include<cstdio>
#include<cstdlib>
#include<vector>
#include "1905001_symbol_table.h"

using namespace std;

#define BUCKET_SIZE 10

int line_count = 1;
int error_count = 0;

ofstream logout;
ofstream tokenout;

// if a string stretches multiple lines, we need to show the starting line no in case of token printing, 
// hence we need to keep the line no. unchanged while the string is running
int inside_line = 0; 

// in case of printing character and strings, if it is unfinished then we print
// characters like \n \b as they are (not their original behaviour), but if they are 
// completed properly, then \n will be replaced by newline...

string cur_char, cur_char_raw;
string cur_string, cur_string_raw;
string cur_comment;
int char_len; // will hold the length of the original one, not raw one

enum error_type {
		MULTICHAR, EMPTY_CHAR, UNFINISHED_CHAR, UNRECOGNIZED, TOO_DECIMAL, 
		ILL_FORMED, INVALID_SUFFIX, UNFINISHED_STRING, UNFINISHED_COMMENT
	};
enum num_type {INTEGER, FLOAT};
enum line_type {SINGLE_LINE, MULTILINE};
enum reset_type {CHAR, STRING, COMMENT};

SymbolTable sym(BUCKET_SIZE);

void reset(reset_type rt) {
	inside_line = 0;
	if (rt == CHAR) {
		cur_char.clear();
		cur_char_raw.clear();
		char_len = 0;
	}
	else if (rt == STRING) {
		cur_string.clear();
		cur_string_raw.clear();
	}
	else if (rt == COMMENT) {
		cur_comment.clear();
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

void printIdentifier() {
	logout << "Line# " << line_count << ": Token <ID> Lexeme " << yytext << " found" << endl;
	tokenout << "<ID, " << yytext << ">" << endl;
	bool success = sym.insert(yytext, "ID", logout);
	if (success) sym.print('A', logout);
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

void printString(line_type lt, const string& str1, const string& str2) {
	if (lt == SINGLE_LINE) {
		logout << "Line# " << line_count << ": Token <SINGLE LINE STRING> Lexeme " << str1 << " found" << endl;
		tokenout << "<SINGLE LINE STRING, " << str2 << ">" << endl; 
	}
	else if (lt == MULTILINE) {
		logout << "Line# " << line_count << ": Token <MULTI LINE STRING> Lexeme " << str1 << " found" << endl;
		tokenout << "<MULTI LINE STRING, " << str2 << ">" << endl;
	}
}

void printComment(line_type lt, const string& str) {
	if (lt == SINGLE_LINE) {
		logout << "Line# " << line_count << ": Token <SINGLE LINE COMMENT> Lexeme " << str << " found" << endl;
	}
	else if (lt == MULTILINE) {
		logout << "Line# " << line_count << ": Token <MULTI LINE COMMENT> Lexeme " << str << " found" << endl;
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
		logout << "TOO_MANY_DECIMAL_POINTS " << str << endl;
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
	else if (e == UNFINISHED_COMMENT) {
		logout << "UNFINISHED_COMMENT " << str << endl;
	}
}

%}

WHITESPACE [ \t\f\r\v]+
LETTER [a-zA-Z]
DIGIT [0-9]
NEWLINE ((\r)?\n)
ALPHABET {LETTER}|_
ALPHANUMERIC {ALPHABET}|{DIGIT}

IDENTIFIER {ALPHABET}{ALPHANUMERIC}*
NON_IDENTIFIER {DIGIT}{ALPHANUMERIC}*

FRACTION (\.{DIGIT}+)

INTEGER {DIGIT}+
FLOATING_POINT (({INTEGER}{FRACTION}?)|{FRACTION})([E][-+]?{INTEGER})?
TOO_DECIMAL ({DIGIT}*(\.{DIGIT}*)\.[-+0-9\.E]*)
ILL_FORMED ({INTEGER}|{FLOATING_POINT})[E]*{FLOATING_POINT}*

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


{IDENTIFIER} 		{ printIdentifier(); }
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


\'					{ BEGIN STATE_CHAR; reset(CHAR); }
\"					{ BEGIN STATE_STRING; reset(STRING); }
\/\/				{ BEGIN STATE_S_COMMENT; reset(COMMENT); }
\/\*				{ BEGIN STATE_STAR_COMMENT; reset(COMMENT); }


<STATE_CHAR>\\\'		{ cur_char += "\'"; cur_char_raw += "\\\'"; char_len++; }
<STATE_CHAR>\\\"		{ cur_char += "\""; cur_char_raw += "\\\""; char_len++; }
<STATE_CHAR>\\n			{ cur_char += "\n"; cur_char_raw += "\\n"; char_len++; }
<STATE_CHAR>\\t			{ cur_char += "\t"; cur_char_raw += "\\t"; char_len++; }
<STATE_CHAR>\\\\		{ cur_char += "\\"; cur_char_raw += "\\\\"; char_len++; }
<STATE_CHAR>\\a			{ cur_char += "\a"; cur_char_raw += "\\a"; char_len++; }
<STATE_CHAR>\\f			{ cur_char += "\f"; cur_char_raw += "\\f"; char_len++; }
<STATE_CHAR>\\r			{ cur_char += "\r"; cur_char_raw += "\\r"; char_len++; }
<STATE_CHAR>\\b			{ cur_char += "\b"; cur_char_raw += "\\b"; char_len++; }
<STATE_CHAR>\\v			{ cur_char += "\v"; cur_char_raw += "\\v"; char_len++; }
<STATE_CHAR>\\0			{ cur_char += "\0"; cur_char_raw += "\\0"; char_len++; }
<STATE_CHAR><<EOF>>		{
							string str = "\'" + cur_char_raw;
							show_error(UNFINISHED_CHAR, str);
							BEGIN INITIAL;
						}
<STATE_CHAR>\'			{	 	
							if (char_len == 0) {
								string str = "\'\'";
								show_error(EMPTY_CHAR, str);
							}
							else if (char_len > 1) {
								string str = "\'" + cur_char_raw + "\'";
								show_error(MULTICHAR, str);
							}
							else printChar(cur_char);
							BEGIN INITIAL;
						}
<STATE_CHAR>{NEWLINE} 	{ 
							string str = "\'" + cur_char_raw;
							show_error(UNFINISHED_CHAR, str); 
							line_count++;
							BEGIN INITIAL;
						}
<STATE_CHAR>.			{ cur_char += yytext[0]; cur_char_raw += yytext[0]; char_len++; }


<STATE_STRING>\\\'		{ cur_string += "\'"; cur_string_raw += "\\\'"; }
<STATE_STRING>\\\"		{ cur_string += "\""; cur_string_raw += "\\\""; }
<STATE_STRING>\\n		{ cur_string += "\n"; cur_string_raw += "\\n"; }
<STATE_STRING>\\t		{ cur_string += "\t"; cur_string_raw += "\\t"; }
<STATE_STRING>\\\\		{ cur_string += "\\"; cur_string_raw += "\\\\"; }
<STATE_STRING>\\a		{ cur_string += "\a"; cur_string_raw += "\\a"; }
<STATE_STRING>\\f		{ cur_string += "\f"; cur_string_raw += "\\f"; }
<STATE_STRING>\\r		{ cur_string += "\r"; cur_string_raw += "\\r"; }
<STATE_STRING>\\b		{ cur_string += "\b"; cur_string_raw += "\\b"; }
<STATE_STRING>\\v		{ cur_string += "\v"; cur_string_raw += "\\v"; }
<STATE_STRING>\\0		{ cur_string += "\0"; cur_string_raw += "\\0"; }
<STATE_STRING>\\{NEWLINE}	{ 
								// an example comment like this: 
								//"abc\
								def"
								// not adding to cur_string, as multiline string ultimately is not multiline
								// the aforementioned string is actually "abcdef"
								// so only add to raw string
								inside_line++; 
								cur_string_raw += yytext;
							}
<STATE_STRING><<EOF>> 	{
							// if error, print the raw version
							string str = "\"" + cur_string_raw;
							line_count += inside_line;
							show_error(UNFINISHED_STRING, str);
							BEGIN INITIAL;
						}
<STATE_STRING>\"		{
							// print the raw version to log file
							// and the original one to token file
							string str = "\"" + cur_string_raw + "\"";
							string str2 = cur_string;
							if (inside_line == 0) printString(SINGLE_LINE, str, str2);
							else printString(MULTILINE, str, str2);
							line_count += inside_line;
							BEGIN INITIAL;
						}
<STATE_STRING>{NEWLINE} {
							// error as multiline string must have '\' at the end of a line
							// if error, print the raw version
							string str = "\"" + cur_string_raw;
							line_count += inside_line;
							show_error(UNFINISHED_STRING, str);
							line_count++;
							BEGIN INITIAL; 
						}
<STATE_STRING>.			{ cur_string += yytext[0]; cur_string_raw += yytext[0]; }


<STATE_S_COMMENT>\\\n		{ inside_line++; cur_comment += "\\\n"; }
<STATE_S_COMMENT>\\\r\n		{ inside_line++; cur_comment += "\\\r\n"; }
<STATE_S_COMMENT>{NEWLINE}	{
								inside_line++;
								string str = "//" + cur_comment;
								printComment(SINGLE_LINE, str);
								line_count += inside_line;
								BEGIN INITIAL;
							}
<STATE_S_COMMENT><<EOF>>	{
								string str = "//" + cur_comment;
								printComment(SINGLE_LINE, str);
								line_count += inside_line;
								BEGIN INITIAL;
							}
<STATE_S_COMMENT>.			{ cur_comment += yytext[0]; }


<STATE_STAR_COMMENT>\n			{ inside_line++; cur_comment += "\n"; } 
<STATE_STAR_COMMENT><<EOF>>	{
								string str = "/*" + cur_comment;
								line_count += inside_line;
								show_error(UNFINISHED_COMMENT, str);
								BEGIN INITIAL;
							}
<STATE_STAR_COMMENT>\*\/	{
								string str = "/*" + cur_comment + "*/";
								printComment(MULTILINE, str);
								line_count += inside_line;
								BEGIN INITIAL;
							}
<STATE_STAR_COMMENT>.		{ cur_comment += yytext[0]; }							


<<EOF>>						{ return 0; }
. 							{ show_error(UNRECOGNIZED, yytext); }

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

	sym.print('A', logout);
	logout << "Total lines: " << line_count << endl;
	logout << "Total errors: " << error_count << endl;

	tokenout.close();
	logout.close();
	return 0;
}
