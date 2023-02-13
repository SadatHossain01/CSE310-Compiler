#pragma once

#include <cassert>
#include <fstream>
#include <iostream>
#include <string>
#include <vector>

using namespace std;

struct Param {
   public:
    string name;
    string data_type;
    bool is_array = false;
    int array_size = 0;
    Param(const string &name, const string &data_type, bool is_array = false, int array_size = 0)
        : name(name), data_type(data_type), is_array(is_array), array_size(array_size) {}
};

enum func_status { NONE, DECLARATION, DEFINITION };

class SymbolInfo {
   private:
    string name;
    string type;
    string data_type;  // should always be in uppercase
    string rule;       // for printing parse tree
    func_status func_type = NONE;
    bool array = false;
    bool terminal = false;
    int start_line = -1, end_line = -1;
    int stack_offset = -1;          // -1 offset means global variable
    vector<Param> param_list;       // name, data_type
    vector<SymbolInfo *> children;  // for parse tree
    SymbolInfo *next = nullptr;

   public:
    SymbolInfo(const string &_name = "", const string &_type = "", const string &_data_type = "")
        : name(_name), type(_type) {
        set_data_type(_data_type);
    }
    SymbolInfo(const SymbolInfo &other) {
        name = other.name;
        type = other.type;
        set_data_type(other.data_type);
        func_type = other.func_type;
        set_array(other.array);
        for (const Param &param : other.param_list) {
            param_list.push_back(param);
        }
        next = nullptr;
    }
    int get_stack_offset() const {
        // assert(stack_offset != -1);
        return stack_offset;
    }
    string get_name() const { return name; }
    string get_type() const { return type; }
    string get_data_type() const { return data_type; }
    string get_rule() const { return rule; }
    func_status get_func_type() const { return func_type; }
    bool is_array() const { return array; }
    bool is_terminal() const { return terminal; }
    int get_start_line() const { return start_line; }
    int get_end_line() const { return end_line; }
    vector<Param> get_param_list() const { return param_list; }
    SymbolInfo *get_next() const { return next; }
    void set_name(const string &name) { this->name = name; }
    void set_type(const string &type) { this->type = type; }
    void set_stack_offset(int offset) { this->stack_offset = offset; }
    void set_data_type(const string &data_type) {
        if (this->data_type != "" && data_type == "") return;
        this->data_type = data_type;
        for (char &c : this->data_type) {
            if ('a' <= c && c <= 'z') c = toupper(c);
        }
    }
    void set_rule(const string &rule) { this->rule = rule; }
    void set_func_type(func_status fs) { this->func_type = fs; }
    void set_array(bool val) {
        this->array = val;
        if (val) this->type = "ARRAY";
    }
    void set_terminal(bool val) { this->terminal = val; }
    void set_line(int start_line, int end_line) {
        this->start_line = start_line;
        this->end_line = end_line;
    }
    void set_start_line(int start_line) { this->start_line = start_line; }
    void set_end_line(int end_line) { this->end_line = end_line; }
    void set_param_list(const vector<Param> &other_param_list) {
        this->param_list.clear();
        for (const Param &param : other_param_list) {
            param_list.push_back(param);
        }
    }
    void add_param(Param param) { this->param_list.push_back(param); }
    void add_param(const string &name, const string &data_type, bool is_array = false) {
        this->param_list.push_back({name, data_type, is_array});
    }
    void add_child(SymbolInfo *child) {
        assert(terminal == false);
        this->children.push_back(child);
        if (this->start_line == -1) this->start_line = child->start_line;
        else this->start_line = min(this->start_line, child->start_line);
        if (this->end_line == -1) this->end_line = child->end_line;
        else this->end_line = max(this->end_line, child->end_line);
    }
    void set_next(SymbolInfo *next) { this->next = next; }
    void print(ostream &out = cout) {
        out << "<" << name << ", ";
        if (type == "FUNCTION") out << "FUNCTION, ";
        else if (array) out << "ARRAY, ";
        out << data_type << "> ";
    }
    void print_tree_node(ostream &out = cout, int level = 0) {
        for (int j = 0; j < level; j++) out << " ";
        out << rule << (terminal ? "" : " ") << "\t";
        out << "<Line: ";
        if (terminal) out << start_line;
        else out << start_line << "-" << end_line;
        out << ">\n";
        for (SymbolInfo *child : children) {
            child->print_tree_node(out,
                                   level + 1);  // lcurls -> LCURL has been handled, so no need to
                                                // check that separately
        }
    }
    ~SymbolInfo() {
        for (SymbolInfo *child : children) {
            delete child;
        }
        children.clear();
        param_list.clear();
    }
};

class ScopeTable {
   private:
    SymbolInfo **arr;
    ScopeTable *parent_scope;
    int id;
    int num_buckets;
    int base_offset = 0;

    unsigned long long SDBMHash(const string &str) {
        unsigned long long hash = 0;
        unsigned int i = 0;
        unsigned int len = str.length();

        for (i = 0; i < len; i++) {
            hash = ((str[i]) + (hash << 6) + (hash << 16) - hash);
        }

        return hash;
    }

    unsigned long long myhash(const string &s) { return SDBMHash(s) % num_buckets; }

   public:
    ScopeTable(int num_buckets, int id) {
        this->num_buckets = num_buckets;
        this->id = id;
        arr = new SymbolInfo *[num_buckets];
        for (int i = 0; i < num_buckets; i++)
            arr[i] = nullptr;  // not writing this caused the initial issues
        parent_scope = nullptr;
        cout << "\t";
        cout << "ScopeTable# " << id << " created\n";
    }

    void set_parent(ScopeTable *par) { parent_scope = par; }
    void set_base_offset(int base_offset) { this->base_offset = base_offset; }
    void set_id(int id) { this->id = id; }
    int get_base_offset() const { return base_offset; }
    int get_id() const { return id; }
    ScopeTable *get_parent() const { return parent_scope; }

    SymbolInfo *search(const string &s) {
        unsigned long long hash_value = myhash(s);
        SymbolInfo *now = arr[hash_value];
        int pos = 0;

        while (now != nullptr) {
            pos++;
            if (now->get_name() == s) {
                // cout << "\t";
                // cout << "\'" << s << "\' found in ScopeTable# " << id
                //      << " at position " << hash_value + 1 << ", " << pos
                //      << "\n";
                return now;
            }
            now = now->get_next();
        }

        return nullptr;
    }

    bool insert(SymbolInfo *si, ostream &out = cout) {
        unsigned long long hash_value = myhash(si->get_name());
        int pos = 0;
        bool success = false;
        SymbolInfo *cur = arr[hash_value];

        if (cur == nullptr) {
            arr[hash_value] = si;
            success = true;
            pos = 1;
        } else {
            pos = 1;

            if (cur->get_name() == si->get_name()) {
                pos = -1;
                success = false;
            }

            while (pos != -1 && cur->get_next() != nullptr) {
                if (cur->get_name() == si->get_name()) {
                    pos = -1;
                    success = false;
                    break;
                }
                cur = cur->get_next();
                pos++;
            }

            if (cur->get_name() == si->get_name()) {
                pos = -1;
                success = false;
            }

            if (pos == -1) {
                // changed the following two lines to print to log file
                // out << "\t";
                // out << "\'" << name
                //     << "\' already exists in the current ScopeTable\n";
                // out << si->get_name()
                //     << " already exists in the current ScopeTable\n";
            }

            else {
                pos++;
                cur->set_next(si);
                success = true;
                // cout << "\t";
                // cout << "Inserted in ScopeTable# " << id << " at position "
                //      << hash_value + 1 << ", " << pos << "\n";
            }
        }

        return success;
    }

    bool remove(const string &s) {
        unsigned long long hash_value = myhash(s);
        SymbolInfo *now = arr[hash_value];

        if (now == nullptr) {
            // cout << "\t";
            // cout << "Not found in the current ScopeTable\n";
            return false;  // no element in this bucket
        }

        int pos = 0;
        bool del = false;

        if (now->get_name() == s) {
            pos = 1;
            SymbolInfo *temp = arr[hash_value]->get_next();
            delete arr[hash_value];
            arr[hash_value] = temp;
            del = true;
        } else {
            pos = 1;
            while (true) {
                pos++;
                if (now == nullptr || now->get_next() == nullptr) break;
                if (now->get_next()->get_name() == s) {
                    SymbolInfo *temp = now->get_next();
                    now->set_next(temp->get_next());
                    del = true;
                    delete temp;
                    break;
                }

                now = now->get_next();
            }
        }

        if (del) {
            // cout << "\t";
            // cout << "Deleted \'" << s << "\' from ScopeTable# " << id
            //      << " at position " << hash_value + 1 << ", " << pos << "\n";
        } else {
            // cout << "\t";
            // cout << "Not found in the current ScopeTable\n";
        }
        return del;
    }

    void print(ostream &out = cout) {
        out << "\tScopeTable# " << id << "\n";

        for (int i = 0; i < num_buckets; i++) {
            if (arr[i] == nullptr) continue;
            out << "\t" << i + 1 << "--> ";
            SymbolInfo *cur = arr[i];
            while (cur != nullptr) {
                cur->print(out);
                cur = cur->get_next();
            }
            out << "\n";
        }
    }

    ~ScopeTable() {
        // first delete all the SymbolInfo objects
        for (int i = 0; i < num_buckets; i++) {
            SymbolInfo *cur = arr[i];
            SymbolInfo *temp;
            while (cur != nullptr) {
                temp = cur->get_next();
                delete cur;
                cur = temp;
            }
        }
        delete[] arr;
        cout << "\t";
        cout << "ScopeTable# " << id << " removed\n";
    }
};

class SymbolTable {
   private:
    ScopeTable *current_scope;
    int num_buckets;
    int scope_cont = 0;
    bool terminated = false;

   public:
    SymbolTable(int num_buckets) {
        this->num_buckets = num_buckets;
        current_scope = new ScopeTable(num_buckets, ++scope_cont);
    }

    void enter_scope() {
        ScopeTable *prev = current_scope;
        current_scope = new ScopeTable(num_buckets, ++scope_cont);
        current_scope->set_parent(prev);
    }

    ScopeTable *get_current_scope() { return current_scope; }

    bool exit_scope() {
        if (current_scope->get_parent() == nullptr) {
            cout << "\t";
            cout << "ScopeTable# " << current_scope->get_id() << " cannot be removed\n";
            return false;  // this is the root scope, can't exit
        } else {
            ScopeTable *temp = current_scope;
            current_scope = current_scope->get_parent();
            delete temp;
            return true;
        }
    }

    bool insert(string name, string type, ostream &out = cout) {
        return current_scope->insert(new SymbolInfo(name, type), out);
    }

    bool insert(SymbolInfo *si, ostream &out = cout) { return current_scope->insert(si, out); }

    bool remove(const string &s) { return current_scope->remove(s); }

    SymbolInfo *search(const string &s, char type) {
        // type = 'C' for current scope, 'A' for all scopes
        ScopeTable *cur = current_scope;
        SymbolInfo *res = cur->search(s);
        if (type == 'C' || type == 'c' || res != nullptr) return res;
        while (true) {
            res = cur->search(s);
            if (res != nullptr) return res;  // search message printed in scope table's search
            else cur = cur->get_parent();
            if (cur == nullptr) {
                // cout << "\t";
                // cout << "\'" << s << "\' not found in any of the
                // ScopeTables\n";
                return nullptr;
            }
        }
    }

    void terminate() {
        while (current_scope->get_parent() != nullptr) {
            exit_scope();
        }
        delete current_scope;
        terminated = true;
    }

    void print(char type, ostream &out = cout) {
        if (type == 'c' || type == 'C') {
            current_scope->print(out);
        } else if (type == 'a' || type == 'A') {
            ScopeTable *cur = current_scope;
            while (true) {
                cur->print(out);
                if (cur->get_parent() == nullptr) return;
                else cur = cur->get_parent();
            }
        }
    }

    ~SymbolTable() {
        if (!terminated) this->terminate();
    }
};