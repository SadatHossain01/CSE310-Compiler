flex -o scanner.c scanner.l
g++ scanner.c -lfl -o a.out
./a.out in.txt
