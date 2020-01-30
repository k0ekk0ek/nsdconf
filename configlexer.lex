%{
/*
 * configlexer.lex - lexical analyzer for NSD config file
 *
 * Copyright (c) 2001-2020, NLnet Labs. All rights reserved
 *
 * See LICENSE for the license.
 *
 */

/* prototype for attribute support and better location tracking */

/* because flex keeps having sign-unsigned compare problems that are unfixed */
#if defined(__clang__)||(defined(__GNUC__)&&((__GNUC__ >4)||(defined(__GNUC_MINOR__)&&(__GNUC__ ==4)&&(__GNUC_MINOR__ >=2))))
#pragma GCC diagnostic ignored "-Wsign-compare"
#endif

#if 0
#include "config.h"
#endif

#include <assert.h>
#include <errno.h>
#include <string.h>
#include <strings.h>
#ifdef HAVE_GLOB_H
# include <glob.h>
#endif

#include "options.h"
#include "configpriv.h"
#include "configparser.h"

#define TRACK_LOCATION(n) \
  do { \
    int i, j; \
    for(i = 0; i < n; i += j) { \
      if(yytext[i] == '\n') { \
        yylloc->last_line++; \
        yylloc->last_column = 1; \
        j = ((i + 1) < n && yytext[i + 1] == '\r') ? 2 : 1; \
      } else if (yytext[i] == '\r') { \
        yylloc->last_line++; \
        yylloc->last_column = 1; \
        j = ((i + 1) < n && yytext[i + 1] == '\n') ? 2 : 1; \
      } else { \
        yylloc->last_column++; \
        j = 1; \
      } \
    } \
    parser->more = 0; \
  } while (0)

/* redefine YY_LESS_LINENO for tracking both line numbers and columns. do NOT
   use %option lineno as location tracking is implemented without using tools
   available in flex itself */
#ifdef YY_LESS_LINENO
#undef YY_LESS_LINENO
#endif

#define YY_LESS_LINENO(n) \
  do { \
    yylloc->last_line = yylloc->first_line; \
    yylloc->last_column = yylloc->first_column; \
    TRACK_LOCATION(n); \
  } while(0);

/* define YY_USER_ACTION to keep track of locations and process include
   directives. the latter is necessary because the nsd configuraton format
   is too liberal in the sense that "server:" in "include: server:" is
   considered a filename, not a token */
#define YY_USER_ACTION \
  /* NOT in do-while so YY_BREAK can be used */ \
  { \
    /* update first position, except if yymore was used */ \
    if(!parser->more) { \
      yylloc->first_line = yylloc->last_line; \
      yylloc->first_column = yylloc->last_column; \
    } \
    /* update last position, except on end-of-file */ \
    if(yytext[0] != '\0') { \
      yylloc->last_line = yylloc->first_line; \
      yylloc->last_column = yylloc->first_column; \
      TRACK_LOCATION(yyleng); \
    } \
    /* ... */ \
    if(YY_START == INCLUDE) { \
      int skip = (strchr("# \t\r\n", yytext[0]) != NULL); \
      if(!skip && yytext[0] != '"') { \
        config_open_glob(parser, yyscanner, yytext); \
        BEGIN(INITIAL); \
        YY_BREAK \
      } \
    } \
  }

#define YY_BREAK \
  do { \
    parser->more = (yyg->yy_more_flag != 0); \
  } while (0); \
  break;

/* define YY_DECL to accept an additional parser argument. declaration is NOT
   shared with Bison because alternative Yacc implementations, like Berkeley
   Yacc, must be supported as well */
#define YY_DECL \
  int yylex(YYSTYPE *yylval_param, \
            YYLTYPE *yylloc_param, \
            yyscan_t yyscanner, \
            struct config_parser_state *parser)

static int
config_open_glob(
  struct config_parser_state *state,
  yyscan_t yyscanner,
  const char *filename);

static void
config_close_file(
  struct config_parser_state *state,
  yyscan_t yyscanner);

%}

%option bison-bridge
%option bison-locations
%option never-interactive
%option noinput
%option nounput
%option noyywrap
%option reentrant

SPACE   [ \t]
NEWLINE (\n\r|\r\n|\n|\r)
COMMENT \#
ANY     ([^\#\"\n\r\t\\ ]|\\.)

%x QUOTED
%x DIRECTIVE
%x PARAMETER
%s INCLUDE

%%

{SPACE} { /* ignore whitespace */ }
{NEWLINE} { /* ignore whitespace */ }
{COMMENT}.* { /* ignore comments */ }

<INCLUDE><<EOF>> {
    config_error(parser, yylloc, "end-of-file inside include directive");
    BEGIN(INITIAL);
  }

\" {
    yymore();
    BEGIN(QUOTED);
  }

<QUOTED><<EOF>> {
    config_error(parser, yylloc, "end-of-file inside quoted string");
    BEGIN(INITIAL);
  }

<QUOTED>([^\"\\]|\\.)* {
    yymore();
  }

<QUOTED>\" {
    BEGIN(INITIAL);
    if(parser->state == INCLUDE) {
      if(yyleng == 2) {
        config_error(parser, yylloc, "empty include file name");
      } else {
        yytext[yyleng - 1] = '\0';
        config_open_glob(parser, yyscanner, yytext + 1);
        parser->state = INITIAL;
        yytext[yyleng - 1] = '\"';
      }
    } else {
      yytext[yyleng - 1] = '\0';
      yylval->str = strdup(yytext + 1);
      //FIXME: yylval->str = region_strdup(parser->opt->region, yytext + 1);
      yytext[yyleng - 1] = '\"';
      return STRING;
    }
  }

[0-9]{1,} {
    yylval->llng = strtoll(yytext, NULL, 10);
    return NUMBER;
  }

yes {
    yylval->bln = 1;
    return BOOLEAN;
  }

no {
    yylval->bln = 0;
    return BOOLEAN;
  }

include:{ANY}* {
    BEGIN(INCLUDE);
    yyless(yyleng - (yyleng - 8));
  }

server-[1-9][0-9]*-cpu-affinity:{ANY}* {
    /* server-<server>-cpu-affinity: is the odd duck where the key actually
       contains a value too. */
    int pos, tok;
    tok = config_istoken("server-cpu-affinity");
    assert(tok != -1);
    pos = strchr(yytext, ':') - yytext;
    yyless(yyleng - (yyleng - pos));
    yylval->llng = strtoll(yytext + 7, NULL, 10);
    return tok;
  }

{ANY}{1,} {
    /* check for directive: and parameter= first so that non-value (NULL)
       directives and parameters can be specified */
    if(yytext[0] == '_' || (yytext[0] >= 'a' && yytext[0] <= 'z')
                        || (yytext[0] >= 'A' && yytext[0] <= 'Z'))
    {
      int brk, tok, pos = 0;
      do {
        pos++;
        brk = !((yytext[pos] == '_') ||
                (yytext[pos] == '-') ||
                (yytext[pos] >= 'a' && yytext[pos] <= 'z') ||
                (yytext[pos] >= 'A' && yytext[pos] <= 'Z') ||
                (yytext[pos] >= '0' && yytext[pos] <= '9'));
      } while(pos < yyleng && !brk);
      /* ... */
      if(yytext[pos] == ':' || yytext[pos] == '=') {
        char chr = yytext[pos];
        yytext[pos] = '\0';
        tok = config_istoken(yytext);
        yytext[pos] = chr;
        if(tok != -1) {
          if(yytext[pos] == ':') {
            parser->state = DIRECTIVE;
          } else {
            parser->state = PARAMETER;
          }
          yyless(yyleng - (yyleng - pos));
          return tok;
        }
      }
    } else if(parser->state == DIRECTIVE ||
              parser->state == PARAMETER)
    {
      int tok = yytext[0];
      assert((yytext[0] == ':' && parser->state == DIRECTIVE) ||
             (yytext[0] == '=' && parser->state == PARAMETER));
      parser->state = INITIAL;
      yyless(yyleng - (yyleng - 1));
      return tok;
    }

    yylval->str = strdup(yytext);
    return STRING;
  }

<<EOF>> {
    config_close_file(parser, yyscanner);
    if(parser->files == NULL) {
      yyterminate();
    }
  }

%%

#define MAX_FILES (10000000)

int
config_open_file(
  struct config_parser_state *parser,
  yyscan_t yyscanner,
  const char *filename)
{
  struct config_file *file = NULL;

  assert(parser != NULL);

  if(parser->file_count >= MAX_FILES) {
    config_error(
      parser, NULL, "maximum number of open files %d reached", MAX_FILES);
    return -1;
  }
  if((file = calloc(1, sizeof(*file))) == NULL ||
     (file->name = strdup(filename)) == NULL ||
     (file->handle = fopen(file->name, "rb")) == NULL)
  {
    config_error(
      parser, NULL, "cannot open '%s': %s", filename, strerror(errno));
    if(file != NULL) {
      if(file->name != NULL) {
        free(file->name);
      }
      free(file);
    }
    return -1;
  }
  /* Yacc keeps a token stack with locations, therefore the filename can be
     referenced after the configuration file has been closed */
  // FIXME: region_add_cleanup(parser->opt->region, free, file->name);
  file->next = parser->files;
  file->line = 1;
  file->column = 1;
  file->buffer = yy_create_buffer(file->handle, YY_BUF_SIZE, yyscanner);
  config_set_location(parser, file->name, file->line, file->column);
  yy_switch_to_buffer(file->buffer, yyscanner);

  parser->file_count++;
  parser->files = file;

  return 0;
}

static int
config_open_glob(
  struct config_parser_state *parser,
  yyscan_t yyscanner,
  const char *filename)
{
  if(parser->chroot != NULL) {
    int len = strlen(parser->chroot); /* chroot has trailing slash */
    if(strncmp(parser->chroot, filename, len) != 0) {
      const char *fmt = "include file '%s' is not relative to chroot '%s'";
      config_error(parser, NULL, fmt, filename, parser->chroot);
      return - 1;
    }
    filename += len - 1; /* strip chroot without trailing slash */
  }
#ifdef HAVE_GLOB
  if(!strchr(filename, '*') && !strchr(filename, '?') &&
     !strchr(filename, '[') && !strchr(filename, '{') &&
     !strchr(filename, '~'))
  {
    glob_t globbuf;
    int flags = 0;
    /* do not set GLOB_NOSORT so files are in predictable order */
#ifdef GLOB_ERR
    flags |= GLOB_ERR;
#endif
#ifdef GLOB_BRACE
    flags |= GLOB_BRACE;
#endif
#ifdef GLOB_TILDE
    flags |= GLOB_TILDE;
#endif

    memset(&globbuf, 0, sizeof(globbuf));
    switch(glob(filename, flags, NULL, &globbuf)) {
      case GLOB_NOSPACE:
      case GLOB_ABORTED:
        return -1;
      case GLOB_NOMATCH:
        break;
      default:
      {
        int i;
        for(i = (int)globbuf.gl_pathc - 1; i >= 0; i--) {
          if(config_open_file(parser, yyscanner, globbuf.gl_pathv[i]) == -1) {
            globfree(&globbuf);
            return -1;
          }
        }
      }
        break;
    }

    globfree(&globbuf);

    return 0;
  }
#endif /* HAVE_GLOB */
  return config_open_file(parser, yyscanner, filename);
}

static void
config_close_file(
  struct config_parser_state *parser,
  yyscan_t yyscanner)
{
  struct config_file *file;

  assert(parser != NULL);
  assert(parser->files != NULL);
  assert(parser->file_count != 0);

  file = parser->files;
  parser->files = parser->files->next;
  parser->file_count--;
  //assert(file->buffer = YY_CURRENT_BUFFER);
  yy_delete_buffer((YY_BUFFER_STATE)file->buffer, yyscanner);
  (void)fclose(file->handle);
  /* filenames are freed when parser region is destroyed */
  free(file);

  if(parser->files != NULL) {
    assert(parser->file_count != 0);
    yy_switch_to_buffer((YY_BUFFER_STATE)parser->files->buffer, yyscanner);
    config_set_location(parser, parser->files->name, parser->files->line, parser->files->column);
  } else {
    assert(parser->file_count == 0);
  }
}
