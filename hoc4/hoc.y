%{
#include <stdio.h>
#include "hoc.h"
#define code2(c1, c2)		code(c1);code(c2)
#define code3(c1, c2, c3)	code(c1);code(c2);code(c3)
int yylex();
void yyerror(char *s);
void execerror(char *s, char *t);
void fpecatch();
extern void init();
extern Inst* code(Inst f);
extern void execute(Inst *p);
extern void initcode();
%}

%union {
    Inst   *inst;  // 指令存放地址
    Symbol *sym;
}
%token	<sym>		NUMBER VAR BLTIN UNDEF
%right '='
%left '+' '-'
%left '*' '/'
%left UNARYMINUS
%right '^'
%%

list:  /* 	nothing */
	| 	list '\n'
	|	list asgn '\n'  { code2((Inst)pop, STOP); return 1;} // yyparse()返回之后，才开始执行指令数组
	| 	list expr '\n'  { code2(print, STOP); return 1; }
	|	list error '\n' { yyerror; }
		;
asgn:		VAR '=' expr    { code3(varpush, (Inst) $1, assign); }
	;
expr:   	NUMBER		{ code2(constpush, (Inst)$1); }
	|	VAR		{ code3(varpush, (Inst)$1, eval); }
	|	asgn
	|	BLTIN '(' expr ')'  { code2( bltin, (Inst)$1->u.ptr ); }
	| '-' 	expr %prec UNARYMINUS { code(negate); }
	| 	expr '+' expr 	{ code(add); }
	| 	expr '-' expr 	{ code(sub); }
	| 	expr '*' expr 	{ code(mul); }
	| 	expr '/' expr 	{ code(zdiv); }
	|	expr '^' expr   { code(power); }
	| '(' 	expr ')'  
		;

%%

#include <ctype.h>
#include <setjmp.h>
jmp_buf begin;
char *progname;
int lineno = 1;

int yylex()
{
  int c;
  while( (c=getchar() )==' ' || c== '\t') ;

  if( c== EOF ) return 0;

  if( c== '.' || isdigit(c) ) {
      double d;
    ungetc(c, stdin);
    scanf("%lf", &d);
    yylval.sym = install("", NUMBER, d); // Symbol增加了一个NUMBER类型
    return NUMBER;
  }
  if( isalpha(c) ) { // 变量标识符的第一个字符必须是字母
      Symbol *s;
      char sbuf[100], *p = sbuf;
      do {
	  *p++ = c;
      } while( (c=getchar()) != EOF && isalnum(c) ); // 后面的字符可以使字母或者数字
      ungetc(c, stdin);
      *p = '\0'; // c语言字符串以\0结尾
      if( (s=lookup(sbuf) ) == 0) s = install(sbuf, UNDEF, 0.0); // 0.0没有意义，仅仅为了占位置。
      yylval.sym = s;
      return s->type==UNDEF ? VAR : s-> type; // 要么是VAR，要么是BLTIN
  }
  if( c=='\n' ) lineno++;
  return c;
}


int main(int argc, char *argv[])
{
	progname = argv[0];
	init();
	setjmp(begin);
	signal(SIGFPE, fpecatch);
	for(initcode(); yyparse(); initcode())  execute(prog);
	return	0;
}


void warning(char *s, char *t) {
  fprintf(stderr, "%s: %s", progname, s);
  if(t)
	fprintf(stderr, " %s", t);
  fprintf(stderr, " near line %d\n", lineno);
}

void yyerror(char *s) {
  warning(s, (char *) 0);
}

void execerror(char *s, char *t) {
    warning(s, t);
    longjmp(begin, 0);
}

void fpecatch() {
    execerror("floating point exception", (char*) 0);
}
