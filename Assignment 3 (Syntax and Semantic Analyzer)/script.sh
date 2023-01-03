flex scanner.l
yacc -d parser.y
g++ lex.yy.c y.tab.c utilities.cpp -o out