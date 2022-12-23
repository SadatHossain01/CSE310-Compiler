%option noyywrap

%x STATE_STRING
%x C_COMMENT
%x CPP_COMMENT

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

// if a string stretches multiple lines, we need to show the starting line no in case of token printing, 
// hence we need to keep the line no. unchanged while the string is running
int inside_line = 0; 

// in case of printing character and strings, if it is unfinished then we print
// characters like \n \b as they are (not their original behaviour), but if they are 
// completed properly, then \n will be replaced by NEWLINE...

string cur_char;
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

char generate_special_character(char c) {
	// MISC [ntafbvr0\'\"\\]
	if (c == 'n') return '\n';
	else if (c == 't') return '\t';
	else if (c == 'a') return '\a';
	else if (c == 'f') return '\f';
	else if (c == 'b') return '\b';
	else if (c == 'v') return '\v';
	else if (c == 'r') return '\r';
	else if (c == '0') return '\0';
	else return c;
}

void reset(reset_type rt) {
	inside_line = 0;
	if (rt == CHAR) {
		cur_char.clear();
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

string get_real_string(string ss) {
    string ret = "";
    const int sz = ss.size();
    for (int i = 0; i < sz; i++) {
        if (ss[i] != '\\') {
            ret += ss[i];
        }
        else {
            if (i == sz - 1) {
                cout << "this should not happen!";
                ret += ss[i];
            }
            else {
                char cc = generate_special_character(ss[i + 1]);
                if (cc == ss[i + 1]) {
                    ret += ss.substr(i, 2);
                }
                else {
                    ret += cc;
                }
                i++;
            }
        }
    }
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

void printNum(num_type nt, const string& str) {
	// if (str[0] == '+' || str[0] == '-') {
	// 	for (int i = 1; i < str.size(); i++) str[i - 1] = str[i];
	// 	str.pop_back();
	// }
	if (nt == INTEGER) {
		tokenout << "<CONST_INT, " << str << ">" << endl;
		logout << "Line# " << line_count << ": Token <CONST_INT> Lexeme " << str << " found" << endl;
	}
	else if (nt == FLOAT) {
		tokenout << "<CONST_FLOAT, " << str << ">" << endl;
		logout << "Line# " << line_count << ": Token <CONST_FLOAT> Lexeme " << str << " found" << endl;
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
NLINE ((\r)?\n)
ALPHABET {LETTER}|_
ALPHANUMERIC {ALPHABET}|{DIGIT}

MISC [ntafbvr0\'\"\\]

IDENTIFIER {ALPHABET}{ALPHANUMERIC}*
NOT_ID {DIGIT}{ALPHANUMERIC}*{ALPHABET}{ALPHANUMERIC}*

CHAR ((\\{MISC})|([^\\\'\n\r]))

INTEGER {DIGIT}+
NUM [-+0-9Ee\.]*
FRACTION (\.{INTEGER})
EXPONENT ([Ee][-+]?{INTEGER})

FLOATING_POINT (({INTEGER}\.?{INTEGER}?{EXPONENT})|({FRACTION}{EXPONENT})|({INTEGER}?{FRACTION})|({INTEGER}\.))

TOO_DECIMAL ([-+]?{DIGIT}*\.{DIGIT}*\.[-+0-9\.Ee]*)
ILL_FORMED ({NUM}*[Ee]{NUM}*\.{NUM}*)|(\.[Ee]{NUM}*[0-9]+{NUM}*)

%%

{WHITESPACE} 			{}
{NLINE} 				{ line_count++; }

"if"					|
"else"					|
"for"					|
"while"					|
"do"					|
"break"					|
"int"					|
"char"					|
"float"					|
"double"				|
"void"					|
"return"				|
"switch"				|
"case"					|
"default"				|
"continue"				{ printKeyword(); }
		

{INTEGER} 				{ printNum(INTEGER, yytext); }
{FLOATING_POINT}		{ printNum(FLOAT, yytext); }
{TOO_DECIMAL}			{ show_error(TOO_DECIMAL, yytext); }
{ILL_FORMED}			{ show_error(ILL_FORMED, yytext); }


{IDENTIFIER} 			{ printIdentifier(); }
{NOT_ID} 				{ show_error(INVALID_SUFFIX, yytext); }


"+"						|
"-"						{ printOpPunc("ADDOP"); }
"*"						|
"/"						|
"%"						{ printOpPunc("MULOP"); }
"++"					|
"--"					{ printOpPunc("INCOP"); }
"<"						|
"<="					|
">"						|
">="					|
"=="					|
"!="					{ printOpPunc("RELOP"); }
"="						{ printOpPunc("ASSIGNOP"); }
"&&"					|
"||"					{ printOpPunc("LOGICOP"); }
"&"						|
"|"						|
"^"						|
"<<"					|
">>"					{ printOpPunc("BITOP"); }
"!"						{ printOpPunc("NOT"); }
"("						{ printOpPunc("LPAREN"); }
")"						{ printOpPunc("RPAREN"); }
"{"						{ printOpPunc("LCURL"); sym.enter_scope(); }
"}"						{ printOpPunc("RCURL"); sym.exit_scope(); }
"["						{ printOpPunc("LSQUARE"); }
"]"						{ printOpPunc("RSQUARE"); }
","						{ printOpPunc("COMMA"); }
";"						{ printOpPunc("SEMICOLON"); }


\"						{ BEGIN STATE_STRING; reset(STRING); }
\/\/					{ BEGIN CPP_COMMENT; reset(COMMENT); }
\/\*					{ BEGIN C_COMMENT; reset(COMMENT); }


\'{CHAR}*\'             {
                            string str = yytext;
                            str.erase(str.begin());
                            str.pop_back(); // removed first and last '
                            cur_char = get_real_string(str);
                            char_len = cur_char.size();
                            if (char_len == 0) {
                                show_error(EMPTY_CHAR, "\'\'");
                            }
                            else if (char_len > 1) {
                                str = "\'" + str + "\'";
                                show_error(MULTICHAR, str);
                            }
                            else printChar(cur_char);
                        }
\'{CHAR}?               {
                            string str = yytext;
                            str.erase(str.begin()); // removed first '
                            cur_char = get_real_string(str);
                            char_len = cur_char.size();
                            str = "\'" + str;
                            show_error(UNFINISHED_CHAR, str);
                            if (yytext[yyleng - 1] == '\n') line_count++;
                        }


<STATE_STRING>\\{MISC}	{ 
							cur_string += generate_special_character(yytext[yyleng - 1]); 
							cur_string_raw += yytext; 
						}
<STATE_STRING><<EOF>> 	{
							// if error, print the raw version
							string str = "\"" + cur_string_raw;
							line_count += inside_line;
							show_error(UNFINISHED_STRING, str);
							BEGIN INITIAL;
						}
<STATE_STRING>\\{NLINE}	{ 
							// an example comment like this: 
							//"abc\
							def"
							// not adding to cur_string, as multiline string ultimately is not multiline
							// the aforementioned string is actually "abcdef"
							// so only add to raw string
							inside_line++; 
							cur_string_raw += yytext;
						}
<STATE_STRING>{NLINE} 	{
							// error as multiline string must have '\' at the end of a line
							// if error, print the raw version
							string str = "\"" + cur_string_raw;
							line_count += inside_line;
							show_error(UNFINISHED_STRING, str);
							line_count++;
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
<STATE_STRING>.			{ 	cur_string += yytext[0]; 
							cur_string_raw += yytext[0]; 
						}


<CPP_COMMENT><<EOF>>	{
							string str = "//" + cur_comment;
							printComment(SINGLE_LINE, str);
							line_count += inside_line;
							BEGIN INITIAL;
						}
<CPP_COMMENT>{NLINE}	{
							inside_line++;
							string str = "//" + cur_comment;
							printComment(SINGLE_LINE, str);
							line_count += inside_line;
							BEGIN INITIAL;
						}
<CPP_COMMENT>\\{NLINE}	{ 
							inside_line++; 
							cur_comment += yytext; 
						}
<CPP_COMMENT>.			{ 
							cur_comment += yytext[0]; 
						}


<C_COMMENT>{NLINE}		{ 
							inside_line++; 
							cur_comment += yytext; 
						}
<C_COMMENT><<EOF>>		{
							string str = "/*" + cur_comment;
							line_count += inside_line;
							show_error(UNFINISHED_COMMENT, str);
							BEGIN INITIAL;
						}
<C_COMMENT>\*\/			{
							string str = "/*" + cur_comment + "*/";
							printComment(MULTILINE, str);
							line_count += inside_line;
							BEGIN INITIAL;
						}
<C_COMMENT>.			{ 
							cur_comment += yytext[0]; 
						}


<<EOF>>					{ return 0; }
. 						{ show_error(UNRECOGNIZED, yytext); }

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