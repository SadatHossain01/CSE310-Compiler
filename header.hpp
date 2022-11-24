#include <string>
using namespace std;

class SymbolInfo {
 private:
  string name, type;
  SymbolInfo* next;

 public:
  string get_name() { return name; }
  string get_type() { return type; }
  void set_name(const string& name) { this->name = name; }
  void set_type(const string& type) { this->type = type; }
};

class ScopeTable {
 private:
  SymbolInfo** arr;
  ScopeTable* parent_scope;
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

  unsigned int myhash(const string& s) { return SDBMHash(s) % num_buckets; }

 public:
  ScopeTable() {}
};