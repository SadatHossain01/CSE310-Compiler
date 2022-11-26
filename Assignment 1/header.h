#include <fstream>
#include <string>
using namespace std;

class SymbolInfo {
   private:
    string name, type;
    SymbolInfo *next;

   public:
    SymbolInfo(string name = "", string type = "") {
        this->name = name;
        this->type = type;
        next = nullptr;
    }
    string get_name() { return name; }
    string get_type() { return type; }
    SymbolInfo *get_next() { return next; }
    void set_name(const string name) { this->name = name; }
    void set_type(const string type) { this->type = type; }
    void set_next(SymbolInfo *next) { this->next = next; }
    void print() { cout << "<" << name << "," << type << ">"; }
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
    ScopeTable(int num_buckets, int id) {
        this->num_buckets = num_buckets;
        this->id = id;
        arr = new SymbolInfo *[num_buckets];
        parent_scope = nullptr;
        cout << "\t";
        cout << "ScopeTable #" << id << " created\n ";
    }

    void set_parent(ScopeTable *par) { parent_scope = par; }

    void set_id(int id) { this->id = id; }

    int get_id() { return id; }

    ScopeTable *get_parent() { return parent_scope; }

    SymbolInfo *search(const string &s) {
        int hash_value = myhash(s);
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

    bool insert(SymbolInfo ss) {
        SymbolInfo *found = search(ss.get_name());
        if (found != nullptr) {
            cout << "\t";
            cout << "\'" << ss.get_name()
                 << "\' already exists in the current ScopeTable\n";
            return false;  // already present, so not possible to insert again
        } else {
            int hash_value = myhash(ss.get_name());
            SymbolInfo *temp = arr[hash_value];
            ss.set_next(nullptr);
            int pos = 0;
            SymbolInfo *si = new SymbolInfo(ss.get_name(), ss.get_type());
            if (temp == nullptr) {
                arr[hash_value] = si;
                pos = 0;
            } else {
                pos++;
                while (temp->get_next() != nullptr) {
                    temp = temp->get_next();
                    pos++;
                }
                temp->set_next(si);
            }
            cout << "\t";
            cout << "Inserted in ScopeTable# " << id << " at position "
                 << hash_value + 1 << ", " << pos + 1 << "\n";
            return true;
        }
    }

    bool remove(const string &s) {
        int hash_value = myhash(s);
        SymbolInfo *now = arr[hash_value];
        if (now == nullptr) return false;  // no element in this bucket
        int pos = 0;
        bool del = false;
        if (now != nullptr && now->get_name() == s) {
            del = true;
            pos = 1;
            delete arr[hash_value];
            arr[hash_value] = nullptr;
        } else {
            pos = 1;
            while (true) {
                pos++;
                if (now->get_next()->get_name() == s) {
                    SymbolInfo *temp = now->get_next();
                    now->set_next(temp->get_next());
                    del = true;
                    delete temp;
                }
                if (now->get_next() == nullptr) break;
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

    void print() {
        cout << "\tScopeTable# " << id << "\n";
        for (int i = 0; i < num_buckets; i++) {
            cout << "\t" << i + 1 << "-->";
            SymbolInfo *cur = arr[i];
            while (cur != nullptr) {
                cur->print();
            }
            cout << "\n";
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
        // cout << "\t";
        // cout << "ScopeTable# " << id << " removed\n";
    }
};

class SymbolTable {
   private:
    ScopeTable *current_scope;
    int num_buckets;
    int scope_cont = 0;

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
            cout << "ScopeTable# 1 cannot be removed\n";
            return false;  // this is the root scope, can't exit
        } else {
            cout << "\t";
            cout << "ScopeTable# " << current_scope->get_id() << " removed\n";
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
            if (cur->get_parent() == nullptr) {
                cout << "\t";
                cout << "\'" << s << "\' not found in any of the ScopeTables\n";
                return nullptr;
            }
        }
    }

    void print(char type) {
        if (type == 'c' || type == 'A') {
            current_scope->print();
        } else {
            ScopeTable *cur = current_scope;
            while (true) {
                cur->print();
                if (cur->get_parent() == nullptr) return;
                else cur = cur->get_parent();
            }
        }
    }
};