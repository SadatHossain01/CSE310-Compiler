yacc -d parser.y
echo 'Generated the parser C file'
flex scanner.l
echo 'Generated the scanner C file'
g++ lex.yy.c y.tab.c utilities.cpp icg_util.cpp -fsanitize=address -g -o out
echo 'All ready, running'
./out $1
rm lex.yy.c y.tab.c y.tab.h error.txt log.txt
