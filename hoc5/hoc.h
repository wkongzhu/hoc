
typedef struct Symbol {
  char *name;
  short type; /* VAR, BLTIN, UNDEF, NUMBER */
  union {
    double val;  // variable
    double (*ptr) (); // build in
  } u;
  struct Symbol *next; //链表指向下一个
} Symbol;

Symbol *install();
Symbol *lookup();

typedef union Datum{ //解释器的堆栈元素类型
  double val;
  Symbol *sym;
} Datum;
extern Datum pop();

typedef void (*Inst)(); // 函数指针作为机器指令, 执行机器指令就是调用函数

#define STOP (Inst)0 // 看到指针为0，停止执行

extern Inst prog[], *progp; // 指令代码数组

extern void eval(), add(), sub(), mul(), zdiv(), negate(), power(),
  assign(), bltin(), varpush(), constpush(), print();
extern void prexpr(), gt(), lt(), eq(), ge(), le(), ne(), and(), or(),
  not(), ifcode(), whilecode();
