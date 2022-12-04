#include <bits/stdc++.h>
using namespace std;

int main() {
    ofstream out;
    out.open("stress.txt");

    for (int i = 0; i < 10000000; i++) {
        out << "S\nI foo FUNCTION\n";
    }

    out.close();
    return 0;
}
