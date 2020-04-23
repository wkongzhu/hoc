YFLAGS := -d
OBJS := hoc.o init.o math.o symbol.o
CC := gcc

hoc3 : $(OBJS)
	gcc $(OBJS) -lm -o $@

hoc.o : hoc.h

init.o symbol.o : hoc.h y.tab.h

clean:
	rm -f *.o y.tab.* hoc*.exe
