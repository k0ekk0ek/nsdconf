/*
 * options.h -- nsd.conf options definitions and prototypes
 *
 * Copyright (c) 2001-2020, NLnet Labs. All rights reserved.
 *
 * See LICENSE for the license.
 *
 */
#ifndef OPTIONS_H
#define OPTIONS_H

#include <stdarg.h>
#include <stdio.h>

typedef struct config_parser_state config_parser_state_type;

struct config_location {
	const char *file;
	int first_line;
	int first_column;
	int last_line;
	int last_column;
};

struct config_file {
	struct config_file *next;
	char *name;
	int line;
	int column;
	FILE *handle;
	void *buffer;
};

struct config_parser_state {
	int file_count;
	struct config_file* files;
	const char* chroot;
	int more;
	int state;
	int errors;
#if 0
	struct nsd_options* opt;
	/* pointer to memory where options for the configuration block that is
	   currently parsed must be stored. memory is dynamically allocated,
	   the block is promoted once it is closed. */
	struct pattern_options *pattern;
	struct zone_options *zone;
	struct key_options *key;
#endif
	void (*err)(void*,const char*);
	void* err_arg;
};

void
config_init_parser(
	struct config_parser_state *parser,
	void (*err)(void*,const char*),
	void* err_arg);

int
config_parse_file(
	struct config_parser_state *parser,
	const char *filename);

void
config_error(
	struct config_parser_state *parser,
	struct config_location *loc,
	const char *fmt,
	...);

void
config_verror(
	struct config_parser_state *parser,
	struct config_location *loc,
	const char *fmt,
	va_list ap);


#endif /* OPTIONS_H */
