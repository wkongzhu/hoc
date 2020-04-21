%{
#include <stdio.h>
double mem[26];
int yylex();
void yyerror(char *s);
void execerror(char *s, char *t);
void fpecatch();
%}

%union {
    double val;
    int index;
}
%token	<val>		NUMBER
%token	<index>		VAR
%type	<val>		expr
%right '='
%left '+' '-'
%left '*' '/'
%left UNARYMINUS 
%%

list:  /* 	nothing */
	| 	list '\n'
	| 	list expr '\n'  { printf("\t%.8g\n", $2); }
	|	list error '\n' { yyerror; }
     ;

expr:   	NUMBER		{ $$ = $1; }
	|	VAR		{ $$ = mem[$1]; }
	|	VAR '=' expr	{ $$ = mem[$1] = $3; }	      
	| '-' 	expr %prec UNARYMINUS { $$ = -$2; }
	| 	expr '+' expr 	{ $$ = $1 + $3; }
	| 	expr '-' expr 	{ $$ = $1 - $3; }
	| 	expr '*' expr 	{ $$ = $1 * $3; }
	| 	expr '/' expr 	{
	    if( $3 == 0.0 )
		execerror("division by zero", "");
	    $$ = $1 / $3;
		}
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
  if( islower(c) ) {
      yylval.index = c - 'a';
      return VAR;
  }
  if( c=='\n' ) lineno++;
  return c;
}


int main(int argc, char *argv[])
{
	progname = argv[0];
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
