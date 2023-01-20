yacc -d parser.y
flex scanner.l
# g++ lex.yy.c y.tab.c utilities.cpp -o out
g++ lex.yy.c y.tab.c utilities.cpp -fsanitize=address -g -o out
# g++ lex.yy.c y.tab.c utilities.cpp -o out
./out errorrecover.c