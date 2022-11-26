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
    ScopeTable(int n) {
        num_buckets = n;
        arr = new SymbolInfo *[n];
    }

    SymbolInfo *search(const string &s) {
        int hash_value = myhash(s);
        SymbolInfo *now = arr[hash_value];
        while (now != nullptr) {
            if (now->get_name() == s) return now;
        }
        return nullptr;
    }

    bool remove(const string &s) {
        int hash_value = myhash(s);
        SymbolInfo *now = arr[hash_value];
        while (true) {
            if (now->get_next()->get_name() == s) {
                SymbolInfo *temp = now->get_next();
                now->set_next(now->get_next()->get_next());
                delete temp;
                return true;
            }
            if (now->get_next() == nullptr) return false;
            now = now->get_next();
        }
    }

    ~ScopeTable() { delete[] arr; }
};

class SymbolTable {
   private:
    ScopeTable *current_scope;

   public:
    void enter_scope() {}
};