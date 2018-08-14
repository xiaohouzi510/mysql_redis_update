all : main

main : lzlib.c
	gcc -g -o $@ $^ -llua -lz -Llib

clean :
	rm -rf main