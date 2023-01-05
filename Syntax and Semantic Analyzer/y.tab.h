#ifndef _yy_defines_h_
#define _yy_defines_h_

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
#ifdef YYSTYPE
#undef  YYSTYPE_IS_DECLARED
#define YYSTYPE_IS_DECLARED 1
#endif
#ifndef YYSTYPE_IS_DECLARED
#define YYSTYPE_IS_DECLARED 1
typedef union YYSTYPE {
	SymbolInfo* symbol_info;
} YYSTYPE;
#endif /* !YYSTYPE_IS_DECLARED */
extern YYSTYPE yylval;

#endif /* _yy_defines_h_ */
