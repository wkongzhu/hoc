#include "hoc.h"
#include "y.tab.h"

#define NSTACK 256
static Datum stack[NSTACK]; // 解释器的栈
static Datum *stackp; // 栈顶指针，指向下一个空闲可用的节点

#define NPROG 2000
Inst prog[NPROG]; // 机器指令数组
Inst *progp; // 指令产生指针，指向下一个空闲可用来存放新产生指令的地方
Inst *pc; // 执行阶段指针，指向下一个要执行的指令

void initcode(){ // 重设栈指针和指令产生指针
  stackp = stack;
  progp  = prog;
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
  while(*pc != STOP) {
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
