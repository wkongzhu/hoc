
typedef struct Symbol {
  char *name;
  short type; /* VAR, BLTIN, UNDEF */
  union {
    double val;  // variable
    double (*ptr) (); // build in
  } u;
  struct Symbol *next; //链表指向下一个
} Symbol;

Symbol *install();
Symbol *lookup();
