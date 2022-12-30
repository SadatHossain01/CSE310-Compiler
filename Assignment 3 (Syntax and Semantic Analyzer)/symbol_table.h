#pragma once

#include <fstream>
#include <iostream>
#include <string>
#include <vector>

using namespace std;

class SymbolInfo {
   private:
    string name;
    string type;
    string data_type;
    bool func_declaration;
    bool func_definition;
    vector<SymbolInfo *> param_list;
    vector<SymbolInfo *> declaration_list;
    SymbolInfo *next;

   public:
    SymbolInfo(const string &name = "", const string &type = "")
        : name(name), type(type) {
        next = nullptr;
    }
    string get_name() const { return name; }
    string get_type() const { return type; }
    string get_data_type() const { return data_type; }
    bool is_func_declaration() const { return func_declaration; }
    bool is_func_definition() const { return func_definition; }
    vector<SymbolInfo *> get_param_list() const { return param_list; }
    vector<SymbolInfo *> get_declaration_list() const {
        return declaration_list;
    }
    SymbolInfo *get_next() const { return next; }
    void set_name(const string &name) { this->name = name; }
    void set_type(const string &type) { this->type = type; }
    void set_data_type(const string &data_type) { this->data_type = data_type; }
    void set_func_declaration(bool val) { this->func_declaration = val; }
    void set_func_definition(bool val) { this->func_definition = val; }
    void set_param_list(const vector<SymbolInfo *> &param_list) {
        this->param_list = param_list;
    }
    void set_declaration_list(const vector<SymbolInfo *> &declaration_list) {
        this->declaration_list = declaration_list;
    }
    void set_next(SymbolInfo *next) { this->next = next; }
    void print(ostream &out = cout) {
        out << "<" << name << "," << type << "> ";
    }
};

class ScopeTable {
   private:
    SymbolInfo **arr;
    ScopeTable *parent_scope;
    int id;
    int num_buckets;

    unsigned long long SDBMHash(const string &str) {
        unsigned long long hash = 0;
        unsigned int i = 0;
        unsigned int len = str.length();

        for (i = 0; i < len; i++) {
            hash = ((str[i]) + (hash << 6) + (hash << 16) - hash);
        }

        return hash;
    }

    unsigned long long myhash(const string &s) {
        return SDBMHash(s) % num_buckets;
    }

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

    void set_id(int id) { this->id = id; }

    int get_id() { return id; }

    ScopeTable *get_parent() { return parent_scope; }

    SymbolInfo *search(const string &s) {
        unsigned long long hash_value = myhash(s);
        SymbolInfo *now = arr[hash_value];
        int pos = 0;

        while (now != nullptr) {
            pos++;
            if (now->get_name() == s) {
                cout << "\t";
                cout << "\'" << s << "\' found in ScopeTable# " << id
                     << " at position " << hash_value + 1 << ", " << pos
                     << "\n";
                return now;
            }
            now = now->get_next();
        }

        return nullptr;
    }

    bool insert(string name, string type, ostream &out = cout) {
        unsigned long long hash_value = myhash(name);
        int pos = 0;
        bool success = false;
        SymbolInfo *cur = arr[hash_value];

        if (cur == nullptr) {
            SymbolInfo *si = new SymbolInfo(name, type);
            arr[hash_value] = si;
            success = true;
            pos = 1;
            // cout << "\t";
            // cout << "Inserted in ScopeTable# " << id << " at position "
            //      << hash_value + 1 << ", " << pos << "\n";
        } else {
            pos = 1;

            if (cur->get_name() == name) {
                pos = -1;
            }

            while (pos != -1 && cur->get_next() != nullptr) {
                if (cur->get_name() == name) {
                    pos = -1;
                    break;
                }
                cur = cur->get_next();
                pos++;
            }

            if (cur->get_name() == name) {
                pos = -1;
            }

            if (pos == -1) {
                // changed the following two lines to print to log file
                out << "\t";
                // out << "\'" << name
                //     << "\' already exists in the current ScopeTable\n";
                out << name << " already exisits in the current ScopeTable\n";
            }

            else {
                pos++;
                SymbolInfo *si = new SymbolInfo(name, type);
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
            cout << "\t";
            cout << "Not found in the current ScopeTable\n";
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
            cout << "\t";
            cout << "Deleted \'" << s << "\' from ScopeTable# " << id
                 << " at position " << hash_value + 1 << ", " << pos << "\n";
        } else {
            cout << "\t";
            cout << "Not found in the current ScopeTable\n";
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

    bool exit_scope() {
        if (current_scope->get_parent() == nullptr) {
            cout << "\t";
            cout << "ScopeTable# " << current_scope->get_id()
                 << " cannot be removed\n";
            return false;  // this is the root scope, can't exit
        } else {
            ScopeTable *temp = current_scope;
            current_scope = current_scope->get_parent();
            delete temp;
            return true;
        }
    }

    bool insert(string name, string type, ostream &out = cout) {
        return current_scope->insert(name, type, out);
    }

    bool remove(const string &s) { return current_scope->remove(s); }

    SymbolInfo *search(const string &s) {
        ScopeTable *cur = current_scope;
        while (true) {
            SymbolInfo *res = cur->search(s);
            if (res != nullptr)
                return res;  // search message printed in scope table's search
            else cur = cur->get_parent();
            if (cur == nullptr) {
                cout << "\t";
                cout << "\'" << s << "\' not found in any of the ScopeTables\n";
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