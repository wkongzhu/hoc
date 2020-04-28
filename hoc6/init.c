#include "hoc.h"
#include "y.tab.h"
#include <math.h>

extern double Log(), Log10(), Exp(), Sqrt(), integer();

static struct{
  char *name;
  double cval;
} consts[] = {
	      "PI",    3.1415926535897,
	      "E",     2.7182818284590,
	      "GAMMA", 0.5772156649015,
	      "DEG",  57.2957795130823,
	      "PHI",   1.6180339887498,
	      0, 0
};

static struct{
  char *name;
  double (*func)();
} builtins[] = {
		"sin",   sin,
		"cos",   cos,
		"atan",  atan,
		"log",   Log,
		"log10", Log10,
		"exp",   Exp,
		"sqrt",  Sqrt,
		"int",   integer,
		"abs",   fabs,
		0, 0
};

static struct {
  char *name;
  int kval;
} keywords[] = {
		"if",		IF,
		"else",		ELSE,
		"while",	WHILE,
		"print",	PRINT,
		"return",	RETURN,
		"proc",		PROC,
		"func",		FUNC,
		"read",		READ,
		0, 0
};
void init() {
  int i;
  Symbol *s;

  for(i=0; consts[i].name; i++) {
    install(consts[i].name, VAR, consts[i].cval);
  }
  for(i=0; builtins[i].name; i++) {
    s = install(builtins[i].name, BLTIN, 0.0);
    s->u.ptr = builtins[i].func;
  }
  for(i=0; keywords[i].name; i++)
    install(keywords[i].name, keywords[i].kval, 0.0);
}
