#include <stdlib.h>
#include <string.h>
#include "hoc.h"
#include "y.tab.h"
extern void execerror(char *s, char *t);

static Symbol *symlist = 0; // 链表开头

Symbol *lookup(char *s) {
  Symbol *sp;

  for(sp=symlist; sp != (Symbol*)0; sp = sp->next) {
    if(strcmp(sp->name, s)==0) // 找到了
      return sp;
  }
  return 0; // 没找到
}

char *emalloc(unsigned n){
  char *p;
  p = malloc(n);
  if(p==0)  execerror("out of memory", (char*) 0);
  return p;
}

Symbol *install( char *s, int t, double d) {
  Symbol *sp;

  sp = (Symbol*) emalloc(sizeof(Symbol));
  sp->name = emalloc(strlen(s) + 1);
  strcpy(sp->name, s);
  sp->type = t;
  sp->u.val = d;
  sp->next = symlist;
  symlist = sp; // symlist总是指向链表头
  return sp;
}
