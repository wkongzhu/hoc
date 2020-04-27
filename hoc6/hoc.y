%{
#include <stdio.h>
#include "hoc.h"
#define code2(c1, c2)		code(c1);code(c2)
#define code3(c1, c2, c3)	code(c1);code(c2);code(c3)
int yylex();
void yyerror(char *s);
void execerror(char *s, char *t);
void fpecatch();
void defnonly(char *s);
extern void init();
extern Inst* code(Inst f);
extern void execute(Inst *p);
extern void initcode();
%}

%union {
    Inst   *inst;  // 指令存放地址
    Symbol *sym;
    int     narg;  // 参数个数
}
%token	<sym>		NUMBER VAR BLTIN UNDEF PRINT WHILE IF ELSE STRING
%token	<sym>		FUNCTION PROCEDURE RETURN FUNC PROC READ
%token	<narg>		ARG
%type	<inst>		stmt asgn expr stmtlist cond while if end prlist begin
%type	<sym>		procname
%type	<narg>		arglist
%right '='
%left OR
%left AND  /* AND优先级高于OR*/
%left GT GE LT LE EQ NE
%left '+' '-'
%left '*' '/'
%left UNARYMINUS NOT
%right '^'
%%

list:  /* 	nothing */
	| 	list '\n'
	|	list defn '\n' // do nothing
	|	list asgn '\n'  { code2((Inst)pop, STOP); return 1;} // yyparse()返回之后，才开始执行指令数组
	|	list stmt '\n'  { code(STOP); return 1;}
	| 	list expr '\n'  { code2(print, STOP); return 1; }
	|	list error '\n' { yyerror; }
		;
asgn:		VAR '=' expr    { $$=$3; code3(varpush, (Inst) $1, assign); }
	|	ARG '=' expr  { defnonly("$"); code2(argassign, (Inst)$1); $$=$3; }
	;
stmt:		expr       { code((Inst) pop); }
	|	RETURN      { defnonly("return"); code(procret); }
	|	RETURN expr { defnonly("return"); code(funcret); $$ = $2; }
	|	PROCEDURE begin '(' arglist ')' { $$=$2; code3(call, (Inst)$1, (Inst)$4); }
	|	PRINT prlist { $$ = $2; }
	|	PRINT expr { code(prexpr); $$ = $2; }
	|	while cond stmt end {
	    ($1)[1] = (Inst)$3;  // body of loop
	    ($1)[2] = (Inst)$4; }
	|	if cond stmt end {
	    ($1)[1] = (Inst)$3;
	    ($1)[3] = (Inst)$4; }
	|	if cond stmt end ELSE stmt end {
	    ($1)[1] = (Inst)$3;
	    ($1)[2] = (Inst)$6;
	    ($1)[3] = (Inst)$7; }
	|	'{' stmtlist '}'  { $$ = $2; }
	;
cond:		'(' expr ')' { code(STOP); $$ = $2; }
	;
while:		WHILE { $$ = code3(whilecode, STOP, STOP); }
	;
if:		IF  { $$ = code(ifcode); code3(STOP, STOP, STOP); }
	;
begin:		/*nothing*/ { $$ = progp };
	;
end:		/*nothing*/ { code(STOP); $$ = progp; }
	;
stmtlist : /*nothting*/  { $$ = progp; }
	|	stmtlist '\n'
	|	stmtlist stmt
		;
expr:   	NUMBER		{ $$ = code2(constpush, (Inst)$1); }
	|	VAR		{ $$ = code3(varpush, (Inst)$1, eval); }
	|	ARG             { defnonly("$"); $$ = code2(arg, (Inst)$1); }
	|	asgn
	|	FUNCTION begin '(' arglist ')' { $$ = $2; code3(call, (Inst)$1, (Inst)$4); }
	|	READ '(' VAR ')' { $$ = code2(varread, (Inst)$3); }	       	       
	|	BLTIN '(' expr ')'  { $$ = $3; code2( bltin, (Inst)$1->u.ptr ); }
	| '-' 	expr %prec UNARYMINUS { $$ = $2; code(negate); }
	| 	expr '+' expr 	{ code(add); }
	| 	expr '-' expr 	{ code(sub); }
	| 	expr '*' expr 	{ code(mul); }
	| 	expr '/' expr 	{ code(zdiv); }
	|	expr '^' expr   { code(power); }
	| '(' 	expr ')'        { $$ = $2; }
	|	expr GT expr    { code(gt); }
	|	expr GE expr    { code(ge); }
	|	expr LT expr    { code(lt); }
	|	expr LE expr    { code(le); }
	|	expr EQ expr    { code(eq); }
	|	expr NE expr    { code(ne); }
	|	expr AND expr   { code(and); }
	|	expr OR expr    { code(or); }
	|	NOT expr        { $$ = $2; code(not); }
		;
prlist:		expr		{ code(prexpr); }
	|	STRING		{ $$ = code2(prstr, (Inst)$1); }
	|	prlist ',' expr { code(prexpr); }
	|	prlist ',' STRING { code2(prexpr, (Inst)$3); }
	;
defn:		FUNC procname { $2->type = FUNCTION; indef = 1; }
		'(' ')' stmt { code(procret); define($2); indef = 0; }
	|	PROC procname { $2->type = PROCEDURE; indef = 1; }
		'(' ')' stmt { code(procret); define($2); indef = 0; }
	;
procname:	VAR
	|	FUNCTION
	|	PROCEDURE
	;
arglist:	 /*nothing*/      { $$ = 0; }
	|	expr		  { $$ = 1; }
	|	arglist ',' expr  { $$ = $1 + 1; }
	;
%%

#include <ctype.h>
#include <setjmp.h>
#include <signal.h>
#include <string.h>
jmp_buf begin;
char *progname;
int lineno = 1;
int indef;
char *infile;
FILE *fin;
char **gargv;
int gargc;

int follow(int expect, int ifyes, int ifno) {
    int c = getchar();
    if(c == expect)   return ifyes;
    else { ungetc(c, stdin); return ifno; }
}

int backslash(int c) {
    char *index();
    static char transtab[] = "b\bf\fn\nr\rt\t"; // 利用了C语言内置的转义功能
    if(c != '\\') return c;
    c = getc(fin);
    if(islower(c) && strchr(transtab, c))  //查表
	return strchr(transtab, c)[1];
    return c;
}

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
  if( c == '$' ) { // $1,$2...是参数
      int n = 0;
      while( isdigit(c=getc(fin)))     n = 10*n + c - '0';
      ungetc(c, fin);
      if(n == 0)  execerror("strange $..., no $0, should start from $1", (char*)0 );
      yylval.narg = n;
      return ARG;
  }
  if( c== '"' ) { // 字符串
      char sbuf[100], *p, *emalloc();
      for(p=sbuf; (c=getc(fin)) != '"'; p++) {
	  if(c=='\n' || c == EOF)  execerror("missing quota", "");
	  if(p>=sbuf+sizeof(sbuf) -1) {
	      *p = '\0';
	      execerror("string too long", sbuf);
	  }
	  *p = backslash(c);
      }
      *p = 0; // 用0取代"，代表字符串结束
      yylval.sym = (Symbol*) emalloc(strlen(sbuf)+1);
      strcpy(yylval.sym, sbuf);
      return STRING;
  }
  //  if( c=='\n' ) lineno++;
  //  return c;
  switch(c) {
  case '>' : return follow('=', GE, GT);
  case '<' : return follow('=', LE, LT);
  case '=' : return follow('=', EQ, '=');
  case '!' : return follow('=', NE, NOT);
  case '|' : return follow('|', OR, '|');
  case '&' : return follow('&', AND, '&');
  case '\n' : lineno++; return '\n';
  default  : return c;
  }
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

void defnonly(char *s) {
    if(!indef)   execerror(s, "used outside definition");
}

