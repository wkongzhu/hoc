YFLAGS := -d
OBJS := hoc.o init.o math.o symbol.o code.o
CC := gcc

hoc4 : $(OBJS)
	gcc $(OBJS) -lm -o $@

hoc.o code.o init.o symbol.o : hoc.h

code.o init.o symbol.o : hoc.h x.tab.h

x.tab.h : y.tab.h
	-cmp -s x.tab.h y.tab.h || cp y.tab.h x.tab.h
clean:
	rm -f *.o [xy].tab.* hoc*.exe
