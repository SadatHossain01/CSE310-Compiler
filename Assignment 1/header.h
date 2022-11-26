#include <fstream>
#include <string>
using namespace std;

class SymbolInfo {
   private:
    string name, type;
    SymbolInfo *next;

   public:
    string get_name() { return name; }
    string get_type() { return type; }
    SymbolInfo *get_next() { return next; }
    void set_name(const string &name) { this->name = name; }
    void set_type(const string &type) { this->type = type; }
    void set_next(SymbolInfo *next) { this->next = next; }
    void print(ofstream &out) { out << "<" << name << "," << type << ">"; }
};

class ScopeTable {
   private:
    SymbolInfo **arr;
    ScopeTable *parent_scope;
    int id;
    int num_buckets;

    unsigned int SDBMHash(string str) {
        unsigned int hash = 0;
        unsigned int i = 0;
        unsigned int len = str.length();

        for (i = 0; i < len; i++) {
            hash = (str[i]) + (hash << 6) + (hash << 16) - hash;
        }

        return hash;
    }

    unsigned int myhash(const string &s) { return SDBMHash(s) % num_buckets; }

   public:
    ScopeTable(int num_buckets) {
        this->num_buckets = num_buckets;
        arr = new SymbolInfo *[num_buckets];
        parent_scope = nullptr;
    }

    void set_parent(ScopeTable *par) { parent_scope = par; }

    void set_id(int id) { this->id = id; }

    ScopeTable *get_parent() { return parent_scope; }

    SymbolInfo *search(const string &s) {
        int hash_value = myhash(s);
        SymbolInfo *now = arr[hash_value];
        while (now != nullptr) {
            if (now->get_name() == s) return now;
        }
        return nullptr;
    }

    bool insert(SymbolInfo ss) {
        SymbolInfo *found = search(ss.get_name());
        if (found != nullptr)
            return false;  // already present, so not possible to insert again
        else {
            int hash_value = myhash(ss.get_name());
            SymbolInfo *temp = arr[hash_value];
            ss.set_next(temp);
            arr[hash_value] = &ss;
        }
    }

    bool remove(const string &s) {
        int hash_value = myhash(s);
        SymbolInfo *now = arr[hash_value];
        if (now == nullptr) return false;  // no element in this bucket
        while (true) {
            if (now->get_next()->get_name() == s) {
                SymbolInfo *temp = now->get_next();
                now->set_next(temp->get_next());
                delete temp;
                return true;  // delete successful
            }
            if (now->get_next() == nullptr)
                return false;  // not found, so break
            now = now->get_next();
        }
    }

    void print(ofstream &out) {
        out << "/tScopeTable# " << id << "\n";
        for (int i = 0; i < num_buckets; i++) {
            out << "/t" << i + 1 << "-->";
            SymbolInfo *cur = arr[i];
            while (cur != nullptr) {
                cur->print(out);
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
    }
};

class SymbolTable {
   private:
    ScopeTable *current_scope;
    int num_buckets;
    int scope_cont;

   public:
    void enter_scope() {
        ScopeTable *prev = current_scope;
        current_scope = new ScopeTable(num_buckets);
        current_scope->set_parent(prev);
        current_scope->set_id(++scope_cont);
    }

    bool exit_scope() {
        if (current_scope->get_parent() == nullptr)
            return false;  // this is the root scope, can't exit
        else {
            current_scope =
                current_scope
                    ->get_parent();  // do I have to explicitly call the
                                     // destructor for the current scope?
            return true;
        }
    }

    bool insert(SymbolInfo ss) { return current_scope->insert(ss); }

    bool remove(const string &s) { return current_scope->remove(s); }

    SymbolInfo *search(const string &s) {
        ScopeTable *cur = current_scope;
        while (true) {
            SymbolInfo *res = cur->search(s);
            if (res != nullptr) return res;
            else cur = cur->get_parent();
            if (cur->get_parent() == nullptr) return nullptr;
        }
    }

    void print_current(ofstream &out) { current_scope->print(out); }

    void print_all(ofstream &out) {
        ScopeTable *cur = current_scope;
        while (true) {
            cur->print(out);
            if (cur->get_parent() == nullptr) return;
            else cur = cur->get_parent();
        }
    }
};