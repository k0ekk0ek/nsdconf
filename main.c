//#include "config.h"

#include <stdio.h>
#include <stdlib.h>

#include "options.h"

int main(int argc, char *argv[])
{
	struct config_parser_state parser;

	config_init_parser(&parser, NULL, NULL);

	if(argc != 2) {
		fprintf(stderr, "Usage: %s FILE\n", argv[0]);
		exit(1);
	}

	config_parse_file(&parser, argv[1]);

	return 0;
}
