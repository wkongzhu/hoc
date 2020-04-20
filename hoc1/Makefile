

hoc1 : y.tab.o
	gcc $< -o $@

y.tab.c : hoc.y
	yacc $<

y.tab.o : y.tab.c
	gcc -c $<


clean:
	rm -f *.o y.tab.c hoc1.exe
