#include <iostream>

#include "header.h"
using namespace std;

int param_count(const string& s) {
    int cont = 0;
    const int sz = s.size();
    for (int i = 0; i < sz; i++) {
        if (s[i] == ' ') continue;
        int idx = i;
        cont++;
        while (idx < sz && s[idx] != ' ') idx++;
        i = idx;
    }
    return cont;
}

void show_error(char fi, char type = 'm') {
    if (type == 'm') {
        // parameter number mismatch
        cout << "\t";
        cout << "Number of parameters mismatch for the command " << fi << "\n";
    }
}

string* tokenize(const string& s, int nn) {
    string* ret = new string[nn];
    int cont = 0;
    const int sz = s.size();
    for (int i = 0; i < sz; i++) {
        if (s[i] == ' ') continue;
        int idx = i;
        int start = i;
        int len = 1;
        while (idx < sz && s[idx] != ' ') {
            idx++;
            len++;
        }
        // cout << s.substr(start, len) << "\n";
        if (cont > 0) ret[cont - 1] = s.substr(start, len);
        i = idx;
        cont++;
    }
    return ret;
}

void trim(string& s) {
    // cout << "Before: " << s << "\n";
    // trims leading and trailing spaces
    int idx = 0;
    while (idx < s.size() && s[idx] == ' ') idx++;
    if (idx == s.size()) {
        s = "";
    } else {
        for (int i = idx; i < s.size(); i++) {
            s[i - idx] = s[i];
        }
        for (int i = 0; i < idx; i++) {
            s.pop_back();
        }
        while (s.back() == ' ') s.pop_back();
    }
    // cout << "After: " << s << "\n";
}

int main() {
    freopen("in.txt", "r", stdin);
    // freopen("out.txt", "w", stdout);

    int n;
    cin >> n;
    int cmd = 0;

    SymbolTable sym(n);
    while (true) {
        string s;
        getline(cin, s);
        trim(s);
        if (s.empty() || s[0] == ' ') continue;
        cout << "Cmd " << ++cmd << ": " << s << "\n";
        char c = s.front();
        int cnt = param_count(s);
        if (c == 'Q') break;
        else if (c == 'I') {
            // insertion
            if (cnt != 3) show_error('m', c);
            else {
                SymbolInfo si;
                string* ret = tokenize(s, 2);
                // cout << ret[0] << " " << ret[1] << "\n";
                si.set_name(ret[0]);
                si.set_type(ret[1]);
                sym.insert(si);
                delete ret;
            }
        } else if (c == 'L') {
            if (cnt != 2) show_error('m', c);
            else {
                string* ret = tokenize(s, 1);
                sym.search(ret[0]);
                delete ret;
            }
        } else if (c == 'D') {
            if (cnt != 2) show_error('m', c);
            else {
                string* ret = tokenize(s, 1);
                sym.remove(ret[0]);
                delete ret;
            }
        } else if (c == 'P') {
            if (cnt != 2) show_error('m', c);
            else {
                string* ret = tokenize(s, 1);
                if (ret[0].size() == 1 && (ret[0] == "A" || ret[0] == "C")) {
                    sym.print(ret[0][0]);
                } else
                    cout << "\t"
                         << "P should be followed by either A or C\n";
                delete ret;
            }
        } else if (c == 'S') {
            if (cnt != 1) show_error('m', c);
            else {
                sym.enter_scope();
            }
        } else if (c == 'E') {
            if (cnt != 1) show_error('m', c);
            else {
                sym.exit_scope();
            }
        } else if (c != ' ') {
            cout << "\t";
            cout << "Invalid Command\n";
        } else {
            cmd--;
        }
    }
}