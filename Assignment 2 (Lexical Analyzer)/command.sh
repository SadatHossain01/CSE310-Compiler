flex -o scanner.c 1905001_scanner.l
g++ scanner.c -lfl -o scanner.out
./scanner.out in.txt
