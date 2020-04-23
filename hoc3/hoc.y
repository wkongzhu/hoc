%{
#include <stdio.h>
#include "hoc.h"
extern double Pow();
int yylex();
void yyerror(char *s);
void execerror(char *s, char *t);
void fpecatch();
extern void init();
%}

%union {
    double val;
    Symbol *sym;
}
%token	<val>		NUMBER
%token	<sym>		VAR BLTIN UNDEF
%type	<val>		expr asgn
%right '='
%left '+' '-'
%left '*' '/'
%left UNARYMINUS
%right '^'
%%

list:  /* 	nothing */
	| 	list '\n'
	|	list asgn '\n'
	| 	list expr '\n'  { printf("\t%.8g\n", $2); }
	|	list error '\n' { yyerror; }
		;
asgn:		VAR '=' expr    { $1->u.val=$3; $1->type=VAR; $$=$1->u.val; }
	;
expr:   	NUMBER		{ $$ = $1; }
	|	VAR		{
	    if($1->type == UNDEF) execerror("undefined variable", $1->name);
	    $$ = $1->u.val;
		}
	|	asgn
	|	BLTIN '(' expr ')'  { $$ = (*($1->u.ptr))($3); }
	| '-' 	expr %prec UNARYMINUS { $$ = -$2; }
	| 	expr '+' expr 	{ $$ = $1 + $3; }
	| 	expr '-' expr 	{ $$ = $1 - $3; }
	| 	expr '*' expr 	{ $$ = $1 * $3; }
	| 	expr '/' expr 	{
	    if( $3 == 0.0 )
		execerror("division by zero", "");
	    $$ = $1 / $3;
		}
|	expr '^' expr { $$ = Pow($1, $3); }
	| '(' 	expr ')'    { $$ = $2; }
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
    ungetc(c, stdin);
    scanf("%lf", &yylval.val);
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

	return	yyparse();
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
