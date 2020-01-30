/*
 * options.c -- options functions.
 *
 * Copyright (c) 2001-2020, NLnet Labs. All rights reserved.
 *
 * See LICENSE for the license.
 *
 */
#if 0
#include "config.h"
#endif

#include <string.h>

#include "options.h"
#include "configpriv.h"

extern int yylex_init(yyscan_t *scanner);
extern void yylex_destroy(yyscan_t *scanner);
extern int yyparse(yyscan_t yyscanner, struct config_parser_state *parser);

void
config_init_parser(
	struct config_parser_state *parser,
	void (*err)(void*,const char*),
	void* err_arg)
{
	memset(parser, 0, sizeof(*parser));
	parser->err = err;
	parser->err_arg = err_arg;
}

int
config_parse_file(
	struct config_parser_state *parser,
	const char *filename)
{
	yyscan_t scanner;

	yylex_init(&scanner);
	if(config_open_file(parser, scanner, filename) != 0) {
		yylex_destroy(scanner);
		return -1;
	}

	/* FIXME: check return value */
	yyparse(scanner, parser);
	yylex_destroy(scanner);

	/* FIXME: do some additional things */

	return 0;
}

void
config_verror(
	struct config_parser_state *parser,
	struct config_location *loc,
	const char *fmt,
	va_list ap)
{
	//char *at;

	parser->errors++;

	if(parser->err) {
		char m[1024]; //MAXSYSLOGMSGLEN];

		if(loc != NULL) {
			snprintf(m, sizeof(m), "%s:%d.%d: ", loc->file, loc->first_line, loc->first_column);
		}
		(*parser->err)(parser->err_arg, m);
                //if(at) {
                //        snprintf(m, sizeof(m), "at '%s': ", at);
                //        (*cfg_parser->err)(cfg_parser->err_arg, m);
                //}
		(*parser->err)(parser->err_arg, "error: ");
		vsnprintf(m, sizeof(m), fmt, ap);
		(*parser->err)(parser->err_arg, m);
		(*parser->err)(parser->err_arg, "\n");
		return;
	}
	if(loc != NULL) {
		fprintf(stderr, "%s:%d.%d: ", loc->file, loc->first_line, loc->first_column);
	}
	//if(at) fprintf(stderr, "at '%s': ", at);
	fprintf(stderr, "error: ");
	vfprintf(stderr, fmt, ap);
	fprintf(stderr, "\n");
}

void
config_error(
	struct config_parser_state *parser,
	struct config_location *loc,
	const char *fmt,
	...)
{
	va_list ap;
	va_start(ap, fmt);
	config_verror(parser, loc, fmt, ap);
	va_end(ap);
}
