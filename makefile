CC = gcc
LEX = flex
YACC = byacc
#YACC = bison

.PHONY: all clear

all: configparser

configparser: configlexer.c configparser.c configparser.h
	$(CC) -g -O0 -Wall -Wextra -o configparser main.c options.c configlexer.c configparser.c

configlexer.c: configlexer.lex
	$(LEX) $(if DEBUG,-T) -o configlexer.c configlexer.lex

configparser.c configparser.h: configparser.y
	$(YACC) $(if DEBUG,-t) -o configparser.c -d configparser.y

clean:
	rm -f configparser *.o configlexer.c configparser.c configparser.h
