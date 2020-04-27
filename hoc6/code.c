#include <stdio.h>
#include <math.h>
#include "hoc.h"
#include "y.tab.h"
extern FILE *fin;

void execerror(char *s, char *t);

#define NSTACK 256
static Datum stack[NSTACK]; // 解释器的栈
static Datum *stackp; // 栈顶指针，指向下一个空闲可用的节点

#define NPROG 2000
Inst prog[NPROG]; // 机器指令数组
Inst *progp; // 指令产生指针，指向下一个空闲可用来存放新产生指令的地方
Inst *pc; // 执行阶段指针，指向下一个要执行的指令

Inst *progbase = prog; // 当前子程序的起始地址
int returning; // 1 if return stmt出现

typedef struct Frame { // proc/func call stack frame
  Symbol *sp;   //符号表入口
  Inst *retpc;  //返回地址
  Datum *argn;  //栈上第n个参数
  int nargs; // 参数个数
} Frame;

#define NFRAME 100
Frame frame[NFRAME];
Frame *fp;

void initcode(){ // 重设栈指针和指令产生指针
  stackp = stack;
  progp  = progbase; // 当前子程序起始
  fp = frame;
  returning = 0;
}

void push(Datum d){
  if(stackp >= &stack[NSTACK])   execerror("stack overflow", (char *) 0);

  *stackp++ = d;
}

Datum pop() {
  if(stackp <= stack)   execerror("stack underflow", (char*) 0);

  return * --stackp;
}

Inst *code(Inst f){
  Inst *oprogp = progp;
  if(progp >= &prog[NPROG]) execerror("program too big", (char*)0 );

  *progp++ = f;
  return oprogp; // 返回当前插入的指令的地址
}

void execute(Inst *p) {
  pc = p;
  while(*pc != STOP && !returning) {
    (* (*pc++) ) ();   // 先取pc指向的函数指针，然后pc=pc+1, 然后调用取出的函数指针指向的函数
  }
}

////////////////////////////////////////////////////////////////
void constpush(){
  Datum d;
  d.val = ((Symbol*)*pc++) ->u.val; //取出指针,转换为Symbol指针，然后获得Symbol指针指向的Number类型Symbol的值
  push(d);
}

void varpush(){
  Datum d;
  d.sym = (Symbol*) (*pc++);
  push(d);
}

void add(){
  Datum d1, d2;
  d2 = pop();
  d1 = pop();
  d1.val += d2.val;
  push(d1);
}

void sub(){
  Datum d1, d2;
  d2 = pop();
  d1 = pop();
  d1.val -= d2.val;
  push(d1);
}

void mul(){
  Datum d1, d2;
  d2 = pop();
  d1 = pop();
  d1.val *= d2.val;
  push(d1);
}

void zdiv(){
  Datum d1, d2;
  d2 = pop();
  d1 = pop();
  if(d2.val == 0.0) execerror("divided by 0", (char*)0);
  d1.val /= d2.val;
  push(d1);
}

void power(){
  Datum d1, d2;
  d2 = pop();
  d1 = pop();
  d1.val = pow(d1.val, d2.val);
  push(d1);
}

void negate(){
  Datum d1;
  d1 = pop();
  d1.val = -d1.val;
  push(d1);
}

void eval() {
  Datum d;
  d = pop();
  if(d.sym->type == UNDEF)    execerror("undefined variable", d.sym->name);

  d.val = d.sym->u.val;
  push(d);
}

void assign() {
  Datum d1, d2;
  d1 = pop();
  d2 = pop();
  if(d1.sym->type != VAR && d1.sym->type != UNDEF)
    execerror("assign to non-variable", d1.sym->name);

  d1.sym->u.val = d2.val;
  d1.sym->type = VAR;
  push(d2);
}

void print() {
  Datum d;
  d = pop();
  printf("\t%.8g\n", d.val);
}

void bltin() {
  Datum d;
  d = pop();  // 将栈顶元素取出来，将其值作为函数计算参数做计算之后再放回去
  d.val = (* (double (*)()) (*pc++) ) (d.val);
  push(d);
}

void le() {
  Datum d1, d2;
  d2 = pop();
  d1 = pop();
  d1.val = (double)(d1.val <= d2.val);
  push(d1);
}

void ge() {
  Datum d1, d2;
  d2 = pop();
  d1 = pop();
  d1.val = (double)(d1.val >= d2.val);
  push(d1);
}

void lt() {
  Datum d1, d2;
  d2 = pop();
  d1 = pop();
  d1.val = (double)(d1.val < d2.val);
  push(d1);
}

void gt() {
  Datum d1, d2;
  d2 = pop();
  d1 = pop();
  d1.val = (double)(d1.val > d2.val);
  push(d1);
}

void eq() {
  Datum d1, d2;
  d2 = pop();
  d1 = pop();
  d1.val = (double)(d1.val == d2.val);
  push(d1);
}

void ne() {
  Datum d1, d2;
  d2 = pop();
  d1 = pop();
  d1.val = (double)(d1.val != d2.val);
  push(d1);
}

void and() {
  Datum d1, d2;
  d2 = pop();
  d1 = pop();
  d1.val = (double)(d1.val != 0.0 && d2.val != 0.0);
  push(d1);
}

void or() {
  Datum d1, d2;
  d2 = pop();
  d1 = pop();
  d1.val = (double)(d1.val != 0.0 || d2.val != 0.0);
  push(d1);
}

void not() {
  Datum d1;
  d1 = pop();
  d1.val = (double)(d1.val==0.0);
  push(d1);
}

void whilecode() {
  Datum d;
  Inst *savepc = pc; // loop body

  execute(savepc + 2); // 先执行判断条件
  d = pop();
  while(d.val) {
    execute(*((Inst **)(savepc))); //循环体
    if(returning)   break;
    execute(savepc + 2);  // 循环条件
    d = pop(); // 得到循环条件计算结果
  }
  if(!returning)
    pc = *((Inst **)(savepc+1)); // 结束while循环
}

void ifcode() {
  Datum d;
  Inst *savepc = pc;
  execute(savepc + 3); // 执行条件判断
  d = pop();
  if(d.val) execute(* ((Inst**)savepc) );
  else if(*((Inst**)(savepc+1))) execute(*((Inst**)(savepc+1)));
  if(!returning)
    pc = *((Inst**)(savepc+2));
}

void prexpr() {
  Datum d;
  d = pop();
  printf("%.8g\n", d.val);
}

void define(Symbol *sp) {
  sp->u.defn = (Inst)progbase;
  progbase = progp;
}

void call() {
  Symbol *sp = (Symbol*)pc[0]; // function的符号表入口
  if(fp++ >= &frame[NFRAME-1])   execerror(sp->name, "call nested too deeply");
  fp->sp = sp;
  fp->nargs = (int) pc[1]; //指针和整数类型占据的内存大小一样
  fp->retpc = pc + 2;
  fp->argn = stackp - 1;
  execute(sp->u.defn);
  returning = 0;
}

void funcret() {
  Datum d;
  if(fp->sp->type == PROCEDURE) execerror(fp->sp->name, "(proc) returns value");
  d = pop();
  ret();
  push(d);
}

void procret() {
  if(fp->sp->type == FUNCTION) execerror(fp->sp->name, "(func) returns no value");
  ret();
}

void ret() {
  int i;
  for(i=0; i < fp->nargs; i++)    pop();
  pc = (Inst*) fp->retpc;
  --fp;
  returning = 1;
}

double *getarg() { // 返回第nargs个参数的指针, 用指针的原因是为了外部修改
  int nargs = (int) *pc++;
  if(nargs > fp->nargs)  execerror(fp->sp->name, "not enough arguments");
  return & fp->argn[nargs - fp->nargs].val;
}

void arg() {
  Datum d;
  d.val = *getarg();
  push(d);
}

void argassign() {
  Datum d;
  d = pop();
  push(d);
  *getarg() = d.val;  //外部修改来赋值参数
}

void prstr() {
  printf("%s", (char*) *pc++);
}

void prexpr() {
  Datum d;
  d = pop();
  printf("%.8g ", d.val);
}

void varread() {
  Datum d;
  Symbol *var = (Symbol*) *pc++;
Again:
  switch(fscanf(fin, "%1f", &var->u.val)) {
  case EOF:
    if ( moreinput() )     goto Again;
    d.val = var->u.val = 0.0;
    break;
  case 0 :
    execerror("non-number read into", var->name);
    break;
  default:
    d.val = 1.0;
    break;
  }
  var->type = VAR;
  push(d);
}

