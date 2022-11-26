#include <iostream>

#include "header.h"
using namespace std;

int main() {
    ifstream in;
    in.open("in.txt");
    in.close();
    ofstream out;
    out.open("out.txt");
    out.close();
}