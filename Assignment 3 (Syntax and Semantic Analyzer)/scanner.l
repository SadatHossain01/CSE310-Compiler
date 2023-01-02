%option noyywrap

%x STATE_STRING
%x C_COMMENT
%x CPP_COMMENT

%{
	
#include <cstdio>
#include <cstdlib>
#include <vector>
#include "symbol_table.h"
#include "y.tab.h"
#include "utilities.h"

using namespace std;

extern SymbolTable* sym;
extern int line_count;
extern int error_count;

extern ofstream logout;

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
	if (rt == CHAR_RESET) {
		cur_char.clear();
		char_len = 0;
	}
	else if (rt == STRING_RESET) {
		cur_string.clear();
		cur_string_raw.clear();
	}
	else if (rt == COMMENT_RESET) {
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
                cerr << "this should not happen!";
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
	// // tokenout << "<" << cap << ", " << yytext << ">" << endl;
	logout << "Line# " << line_count << ": Token <" << cap << "> Lexeme " << yytext << " found" << endl;
}

void printIdentifier() {
	logout << "Line# " << line_count << ": Token <ID> Lexeme " << yytext << " found" << endl;
	// tokenout << "<ID, " << yytext << ">" << endl;
	bool success = sym->insert(yytext, "ID", logout);
	// if (success) sym->print('A', logout);
}

void printNum(num_type nt, const string& str) {
	// if (str[0] == '+' || str[0] == '-') {
	// 	for (int i = 1; i < str.size(); i++) str[i - 1] = str[i];
	// 	str.pop_back();
	// }
	if (nt == INTNUM) {
		// tokenout << "<CONST_INT, " << str << ">" << endl;
		logout << "Line# " << line_count << ": Token <CONST_INT> Lexeme " << str << " found" << endl;
	}
	else if (nt == FLOATNUM) {
		// tokenout << "<CONST_FLOAT, " << str << ">" << endl;
		logout << "Line# " << line_count << ": Token <CONST_FLOAT> Lexeme " << str << " found" << endl;
	}
}

void printOpPunc(const string& token) {
	// tokenout << "<" << token << ", " << yytext << ">" << endl;
	logout << "Line# " << line_count << ": Token <" << token << "> Lexeme " << yytext << " found" << endl;	
}

void printChar(const string& str) {
	// tokenout << "<CONST_CHAR, " << str << ">" << endl;
	logout << "Line# " << line_count << ": Token <CONST_CHAR> Lexeme " << str << " found" << endl;
}

void printString(line_type lt, const string& str1, const string& str2) {
	if (lt == SINGLE_LINE) {
		logout << "Line# " << line_count << ": Token <SINGLE LINE STRING> Lexeme " << str1 << " found" << endl;
		// tokenout << "<SINGLE LINE STRING, " << str2 << ">" << endl; 
	}
	else if (lt == MULTILINE) {
		logout << "Line# " << line_count << ": Token <MULTI LINE STRING> Lexeme " << str1 << " found" << endl;
		// tokenout << "<MULTI LINE STRING, " << str2 << ">" << endl;
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
{NLINE} 				{ 
							line_count++; 
						}

"if"					{
							printKeyword();
							yylval.symbol_info = new SymbolInfo(yytext, "KEYWORD");
							return IF;
						}
"else"					{
							printKeyword();
							yylval.symbol_info = new SymbolInfo(yytext, "KEYWORD");
							return ELSE;
						}
"for"					{
							printKeyword();
							yylval.symbol_info = new SymbolInfo(yytext, "KEYWORD");
							return FOR;
						}
"while"					{
							printKeyword();
							yylval.symbol_info = new SymbolInfo(yytext, "KEYWORD");
							return WHILE;
						}
"do"					{
							printKeyword();
							yylval.symbol_info = new SymbolInfo(yytext, "KEYWORD");
							return DO;
						}
"break"					{
							printKeyword();
							yylval.symbol_info = new SymbolInfo(yytext, "KEYWORD");
							return BREAK;
						}
"int"					{
							printKeyword();
							yylval.symbol_info = new SymbolInfo(yytext, "KEYWORD");
							return INT;
						}
"char"					{
							printKeyword();
							yylval.symbol_info = new SymbolInfo(yytext, "KEYWORD");
							return CHAR;
						}
"float"					{
							printKeyword();
							yylval.symbol_info = new SymbolInfo(yytext, "KEYWORD");
							return FLOAT;
						}
"double"				{
							printKeyword();
							yylval.symbol_info = new SymbolInfo(yytext, "KEYWORD");
							return DOUBLE;
						}
"void"					{
							printKeyword();
							yylval.symbol_info = new SymbolInfo(yytext, "KEYWORD");
							return VOID;
						}
"return"				{
							printKeyword();
							yylval.symbol_info = new SymbolInfo(yytext, "KEYWORD");
							return RETURN;
						}
"switch"				{
							printKeyword();
							yylval.symbol_info = new SymbolInfo(yytext, "KEYWORD");
							return SWITCH;
						}
"case"					{
							printKeyword();
							yylval.symbol_info = new SymbolInfo(yytext, "KEYWORD");
							return CASE;
						}
"default"				{
							printKeyword();
							yylval.symbol_info = new SymbolInfo(yytext, "KEYWORD");
							return DEFAULT;
						}
"continue"				{
							printKeyword();
							yylval.symbol_info = new SymbolInfo(yytext, "KEYWORD");
							return CONTINUE;
						}
"printf"				{
							printKeyword();
							yylval.symbol_info = new SymbolInfo(yytext, "KEYWORD");
							return PRINTF;
						}
"println"				{
							printKeyword();
							yylval.symbol_info = new SymbolInfo(yytext, "KEYWORD");
							return PRINTLN;
						}
		

{INTEGER} 				{ 
							printNum(INTNUM, yytext); 
							yylval.symbol_info = new SymbolInfo(yytext, "CONST_INT", "int");
							return CONST_INT;
						}
{FLOATING_POINT}		{ 
							printNum(FLOATNUM, yytext); 
							yylval.symbol_info = new SymbolInfo(yytext, "CONST_FLOAT", "float");
							return CONST_FLOAT;
 						}
{TOO_DECIMAL}			{ 
							show_error(LEXICAL, TOO_DECIMAL, yytext, logout); 
						}
{ILL_FORMED}			{ 
							show_error(LEXICAL, ILL_FORMED, yytext, logout); 
						}


{IDENTIFIER} 			{ 
							printIdentifier(); 
							yylval.symbol_info = new SymbolInfo(yytext, "ID"); // if it is a variable declaration, set its data type field in parser.y and use that
							return ID;
						}
{NOT_ID} 				{ 
							show_error(LEXICAL, INVALID_SUFFIX, yytext, logout); 
						}


"+"						|
"-"						{ 	printOpPunc("ADDOP");
							yylval.symbol_info = new SymbolInfo(yytext, "ADDOP");
							return ADDOP;
						}
"*"						|
"/"						|
"%"						{ 	printOpPunc("MULOP");
							yylval.symbol_info = new SymbolInfo(yytext, "MULOP");
							return MULOP;
						}
"++"					{ 	printOpPunc("INCOP");
							yylval.symbol_info = new SymbolInfo(yytext, "INCOP");
							return INCOP;
						}
"--"					{ 	printOpPunc("DECOP");
							yylval.symbol_info = new SymbolInfo(yytext, "DECOP");
							return DECOP;
						}
"<"						|
"<="					|
">"						|
">="					|
"=="					|
"!="					{ 	printOpPunc("RELOP");
							yylval.symbol_info = new SymbolInfo(yytext, "RELOP");
							return RELOP;
						}
"="						{ 	printOpPunc("ASSIGNOP");
							yylval.symbol_info = new SymbolInfo(yytext, "ASSIGNOP");
							return ASSIGNOP;
						}
"&&"					|
"||"					{ 	printOpPunc("LOGICOP");
							yylval.symbol_info = new SymbolInfo(yytext, "LOGICOP");
							return LOGICOP;
						}
"&"						|
"|"						|
"^"						|
"<<"					|
">>"					{ 	printOpPunc("BITOP");
							yylval.symbol_info = new SymbolInfo(yytext, "BITOP");
							return BITOP;
						}
"!"						{ 	printOpPunc("NOT");
							yylval.symbol_info = new SymbolInfo(yytext, "NOT");
							return NOT;
						}
"("						{ 	printOpPunc("LPAREN");
							yylval.symbol_info = new SymbolInfo(yytext, "LPAREN");
							return LPAREN;
						}
")"						{ 	printOpPunc("RPAREN");
							yylval.symbol_info = new SymbolInfo(yytext, "RPAREN");
							return RPAREN;
						}
"{"						{ 	printOpPunc("LCURL");
							yylval.symbol_info = new SymbolInfo(yytext, "LCURL");
							sym->enter_scope();
							return LCURL;
						}
"}"						{ 	printOpPunc("RCURL");
							yylval.symbol_info = new SymbolInfo(yytext, "RCURL");
							sym->exit_scope();
							sym->print('A', logout);
							return RCURL;
						}
"["						{ 	printOpPunc("LTHIRD");
							yylval.symbol_info = new SymbolInfo(yytext, "LTHIRD");
							return LTHIRD;
						}
"]"						{ 	printOpPunc("RTHIRD");
							yylval.symbol_info = new SymbolInfo(yytext, "RTHIRD");
							return RTHIRD;
						}
","						{ 	printOpPunc("COMMA");
							yylval.symbol_info = new SymbolInfo(yytext, "COMMA");
							return COMMA;
						}
";"						{ 	printOpPunc("SEMICOLON");
							yylval.symbol_info = new SymbolInfo(yytext, "SEMICOLON");
							return SEMICOLON;
						}


\"						{ 
							BEGIN STATE_STRING; 
							reset(STRING_RESET); 
						}
\/\/					{ 
							BEGIN CPP_COMMENT; 
							reset(COMMENT_RESET); 
						}
\/\*					{ 
							BEGIN C_COMMENT; 
							reset(COMMENT_RESET); 
						}


\'{CHAR}*\'             {
                            string str = yytext;
                            str.erase(str.begin());
                            str.pop_back(); // removed first and last '
                            cur_char = get_real_string(str);
                            char_len = cur_char.size();
                            if (char_len == 0) {
                                show_error(LEXICAL, EMPTY_CHAR, "\'\'", logout);
                            }
                            else if (char_len > 1) {
                                str = "\'" + str + "\'";
                                show_error(LEXICAL, MULTICHAR, str, logout);
                            }
                            else printChar(cur_char);
                        }
\'{CHAR}?               {
                            string str = yytext;
                            str.erase(str.begin()); // removed first '
                            cur_char = get_real_string(str);
                            char_len = cur_char.size();
                            str = "\'" + str;
                            show_error(LEXICAL, UNFINISHED_CHAR, str, logout);
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
							show_error(LEXICAL, UNFINISHED_STRING, str, logout);
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
							show_error(LEXICAL, UNFINISHED_STRING, str, logout);
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
							show_error(LEXICAL, UNFINISHED_COMMENT, str, logout);
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
. 						{ show_error(LEXICAL, UNRECOGNIZED, yytext, logout); }

%%