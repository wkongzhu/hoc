YFLAGS := -d
OBJS := hoc.o init.o math.o symbol.o code.o
CC := gcc 

hoc6 : $(OBJS)
	$(CC) $(OBJS)  -o $@

hoc.o code.o init.o symbol.o : hoc.h

code.o init.o symbol.o : x.tab.h

x.tab.h : y.tab.h
	-cmp -s x.tab.h y.tab.h || cp y.tab.h x.tab.h
clean:
	rm -f *.o [xy].tab.* hoc*.exe

t_fac: hoc6
	hoc6 fac
t_fib: hoc6
	hoc6 fib
