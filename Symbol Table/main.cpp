#include <iostream>
#include <sstream>

#include "symbol_table.h"
using namespace std;

void trim(string& s) {
    // trims leading and trailing spaces
    //  cout << "before: " << s << " ";
    int idx = 0;
    while (idx < s.size() && s[idx] == ' ') idx++;
    if (idx == s.size()) {
        s = "";
        // cout << "after: " << s << "\n";
        return;
    }
    for (int i = idx; i < s.size(); i++) s[i - idx] = s[i];
    for (int i = 0; i < idx; i++) s.pop_back();
    // cout << "after: " << s << "\n";
}

string remove_redundant_spaces(const string& s) {
    string ret = "";
    // cout << "Given: " << s << "\n";
    const int sz = s.size();
    for (int i = 0; i < sz; i++) {
        if (s[i] == ' ') continue;
        int idx = i;
        while (idx < sz && s[idx] != ' ') idx++;
        // so from i to idx - 1 is a token
        ret += s.substr(i, idx - i) + " ";
        i = idx - 1;
    }
    if (ret.back() == ' ') ret.pop_back();
    // cout << "Returned: " << ret << "\n";
    return ret;
}

int char_count(const string& s, char c) {
    int cont = 0;
    for (char cc : s) {
        if (cc == c) cont++;
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

int main() {
    freopen("in.txt", "r", stdin);
    freopen("out.txt", "w", stdout);

    int n;
    cin >> n;
    cin.ignore();
    int cmd = 0;

    SymbolTable st(n);

    while (true) {
        string s;
        getline(cin, s);
        cout << "Cmd " << ++cmd << ": " << s << "\n";

        string concise = remove_redundant_spaces(s);
        stringstream line(concise);
        string ss;

        char start = s.front();
        int sp_count = char_count(concise, ' ');
        string comm;

        if (start == 'I') {
            if (sp_count != 2) show_error(start, 'm');
            else {
                string name, type;
                getline(line, comm, ' ');
                getline(line, name, ' ');
                getline(line, type, ' ');
                // cout << name << " " << type << "\n";
                st.insert(name, type);
            }
        }

        else if (start == 'L') {
            if (sp_count != 1) show_error(start, 'm');
            else {
                string key;
                getline(line, comm, ' ');
                getline(line, key, ' ');
                // cout << key << "\n";
                st.search(key);
            }
        }

        else if (start == 'D') {
            if (sp_count != 1) show_error(start, 'm');
            else {
                string key;
                getline(line, comm, ' ');
                getline(line, key, ' ');
                // cout << key << "\n";
                st.remove(key);
            }
        }

        else if (start == 'P') {
            if (sp_count != 1) show_error(start, 'm');
            else {
                st.print(concise[2]);
            }
        }

        else if (start == 'S') {
            if (sp_count != 0) show_error(start, 'm');
            else st.enter_scope();
        }

        else if (start == 'E') {
            if (sp_count != 0) show_error(start, 'm');
            else st.exit_scope();
        }

        else if (start == 'Q') {
            if (sp_count != 0) show_error(start, 'm');
            else {
                st.terminate();
                break;
            }
        }
    }
}