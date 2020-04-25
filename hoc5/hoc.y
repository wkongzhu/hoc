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
%token	<sym>		NUMBER VAR BLTIN UNDEF PRINT WHILE IF ELSE
%type	<inst>		stmt asgn expr stmtlist cond while if end
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
	|	list asgn '\n'  { code2((Inst)pop, STOP); return 1;} // yyparse()返回之后，才开始执行指令数组
	|	list stmt '\n'  { code(STOP); return 1;}
	| 	list expr '\n'  { code2(print, STOP); return 1; }
	|	list error '\n' { yyerror; }
		;
asgn:		VAR '=' expr    { $$=$3; code3(varpush, (Inst) $1, assign); }
	;
stmt:		expr       { code((Inst) pop); }
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
end:		/*nothing*/ { code(STOP); $$ = progp; }
	;
stmtlist : /*nothting*/  { $$ = progp; }
	|	stmtlist '\n'
	|	stmtlist stmt
		;
expr:   	NUMBER		{ $$ = code2(constpush, (Inst)$1); }
	|	VAR		{ $$ = code3(varpush, (Inst)$1, eval); }
	|	asgn
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

%%

#include <ctype.h>
#include <setjmp.h>
jmp_buf begin;
char *progname;
int lineno = 1;

int follow(int expect, int ifyes, int ifno) {
    int c = getchar();
    if(c == expect)   return ifyes;
    else { ungetc(c, stdin); return ifno; }
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
