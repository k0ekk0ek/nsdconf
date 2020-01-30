/*
 * configparser.y -- yacc grammar for NSD configuration files
 *
 * Copyright (c) 2001-2020, NLnet Labs. All rights reserved.
 *
 * See LICENSE for the license.
 *
 */

/* prototype for attribute support and better location tracking */

%{
#if 0
#include "config.h"
#endif

#include <assert.h>
#include <errno.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

#include "options.h"
#include "configpriv.h"

#define YYDEBUG 1 /* make yyname available */
#ifdef YYBISON
/* make yytoknum available */
#define YYPRINT(A,B,C) YYUSE(A)
#endif

/* override yyparse to support additional parameters */
#define yyparse(...) \
  yyparse(yyscan_t yyscanner, struct config_parser_state *parser)

#include "configparser.h"

extern int yylex(
  YYSTYPE *yylval_param,
  YYLTYPE *yylloc_param,
  yyscan_t yyscanner,
  struct config_parser_state *pstate);

/* override yylex to support additional parameters */
#define yylex(...) \
  yylex(&yylval, &yylloc, yyscanner, parser)

/* use a static variable until %locations (Bison and btyacc compiled with --enable-locations) are supported */
static YYLTYPE yylloc;

#define yyerror(msg) config_error(parser, &yylloc, msg)

static int parse_boolean(const char *str, int *bln);
static int parse_number(const char *str, long long *num);
%}

%union {
  char *str;
  long long llng;
  int bln;
}

%token <str> STRING
%token <llng> NUMBER
%token <bln> BOOLEAN

/* server */
%token VAR_SERVER
%token VAR_SERVER_COUNT
%token <str> VAR_IP_ADDRESS

/* socket options */
%token VAR_SERVERS
%token VAR_SETFIB
%token VAR_BINDTODEVICE
%token VAR_RCVBUF
%token VAR_RECEIVE_BUFFER_SIZE /* deprecated, use rcvbuf */
%token VAR_SNDBUF
%token VAR_SEND_BUFFER_SIZE /* deprecated, use sndbuf */
%token VAR_IP_FREEBIND
%token VAR_IP_TRANSPARENT

%type <llng> number
%type <bln> boolean
%type <str> ip_address

%%

blocks:
  | blocks block
  ;

block:
    server
  ;

server:
    VAR_SERVER ':' server_block
  ;

server_block:
  | server_block server_options
  ;

server_options:
    VAR_SERVER_COUNT ':' number
    { printf("server-count: %d\n", (int)$3); }
  | VAR_IP_ADDRESS ':' ip_address
    {
      printf("ip-address: %s\n", $3);
    }
    socket_options
  | VAR_IP_FREEBIND ':' boolean
    { printf("ip-freebind: %d\n", (int)$3); }
  | VAR_IP_TRANSPARENT ':' boolean
    { printf("ip-transparent: %d\n", (int)$3); }
  | rcvbuf ':' number
    { printf("rcvbuf: %d\n", (int)$3); }
  | sndbuf ':' number
    { printf("sndbuf: %d\n", (int)$3); }
  ;

ip_address:
    STRING
    { $$ = $1; }
  ;

socket_options:
  | socket_options socket_option ;

socket_option:
  | VAR_SERVERS '=' number
    { printf("  servers: %d\n", (int)$3); }
  | VAR_SERVERS '=' STRING
    { printf("  servers: %s\n", $3); }
  | VAR_SETFIB '=' number
    { printf("  setfib: %d\n", (int)$3); }
  | VAR_BINDTODEVICE '=' boolean
    { printf("  bindtodevice: %s\n", $3 ? "yes" : "no");  }
  | VAR_RCVBUF '=' number
    { /* set SO_RCVBUF specifically for this socket */
      printf("  rcvbuf: %lld\n", $3);
    }
  | VAR_SNDBUF '=' number
    { /* set SO_SNDBUF specifically for this socket */
      printf("  sndbuf: %lld\n", $3);
    }
  ;

rcvbuf: VAR_RCVBUF | VAR_RECEIVE_BUFFER_SIZE ;

sndbuf: VAR_SNDBUF | VAR_SEND_BUFFER_SIZE ;

number:
    NUMBER
    { $$ = $1; }
  | STRING
    {
      if(!parse_number($1, &$$)) {
        yyerror("expected a number");
        YYABORT; /* trigger parser error */
      }
    }
  ;

boolean:
    BOOLEAN
    { $$ = $1; }
  | STRING
    {
      if(!parse_boolean($1, &$$)) {
        yyerror("expected yes or no");
        YYABORT; /* trigger parser error */
      }
    }
  ;

%%

static int
parse_boolean(const char *str, int *bln)
{
  if(strcmp(str, "yes") == 0) {
    *bln = 1;
  } else if(strcmp(str, "no") == 0) {
    *bln = 0;
  } else {
    return 0;
  }

  return 1;
}

static int
parse_number(const char *str, long long *num)
{
  /* ensure string consists entirely of digits */
  int i = 0;
  while(str[i] >= '0' && str[i] <= '9') {
    i++;
  }

  if(i != 0 && str[i] == '\0') {
    *num = strtoll(str, NULL, 10);
    return 1;
  }

  return 0;
}

void
config_set_location(
  struct config_parser_state *parser,
  const char *file,
  int line,
  int column)
{
  (void)parser;
  yylloc.file = file;
  yylloc.first_line = yylloc.last_line = line;
  yylloc.first_column = yylloc.last_column = column;
}

static int tnamecmp(const char *str, const char *tname)
{
  char chr;
  size_t i, j;

  assert(str != NULL);
  assert(tname != NULL);

  if(strncmp("VAR_", tname, 4) != 0) {
    return -1;
  }

  i = 0;
  j = 4;

  while(str[i] != '\0' && tname[j] != '\0') {
    if(str[i] >= 'A' && str[i] <= 'Z') {
      if(str[i] != tname[j]) {
        return -1;
      }
      return -1;
    } else if (str[i] >= 'a' && str[i] <= 'z') {
      chr = (str[i] - 'a') + 'A';
      if(chr != tname[j]) {
        return -1;
      }
    } else if ((str[i] == '-' && tname[j] != '_') &&
               (str[i] != tname[j]))
    {
      return -1;
    }
    i++;
    j++;
  }

  return str[i] != tname[j] ? -1 : 0;
}

int config_istoken(const char *str)
{
#ifdef YYBISON /* Bison */
#define TOK_TABLE yytname
#define TOK_MIN (0)
#define TOK_MAX (YYNTOKENS)
#define TOK(i) (yytoknum[i])
#else /* e.g. Yacc and Berkeley Yacc */
#define TOK_TABLE yyname
#define TOK_MIN (255)
#define TOK_MAX (YYMAXTOKEN)
#define TOK(i) (i)
#endif

  assert(str != NULL);

  for(int i=TOK_MIN; i < TOK_MAX; i++) {
    if(TOK_TABLE[i] && tnamecmp(str, TOK_TABLE[i]) == 0) {
      return TOK(i);
    }
  }

  return -1;
}
