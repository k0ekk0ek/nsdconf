/*
 * configpriv.h -- renames for config file yy values to avoid conflicts
 *
 * Copyright (c) 2001-2020, NLnet Labs. All rights reserved.
 *
 * See LICENSE for the license.
 *
 */

/* prototype for attribute support and better location tracking */

#ifndef CONFIGPRIV_H
#define CONFIGPRIV_H

typedef void *yyscan_t;

int
config_open_file(
	struct config_parser_state *parser,
	yyscan_t yyscanner,
	const char *filename);

void
config_set_location(
	struct config_parser_state *parser,
	const char *file,
	int line,
	int column);

int
config_istoken(
	const char *str);


/* override YYLTYPE declared by Bison or btyacc with --enable-locations */
#define YYLTYPE_IS_DECLARED 1
typedef struct config_location YYLTYPE;


/* YYPREFIX is used in configlexer.lex and configparser.y too */
#define YYRENAME(func) c_ ## func

#if 0
#ifdef FLEX_SCANNER
/* yylex, or rather YY_DECL, is defined in configlexer.lex */
#else
/* yyparse and yylex are defined in configparser.y */
/* yylval and yylloc must not be renamed in flex generated scanner */
#define yylval                       YYRENAME(lval)
#define yylloc                       YYRENAME(lloc)
#endif

#define yymaxdepth                   YYRENAME(maxdepth)
#define yychar                       YYRENAME(char)
#define yydebug                      YYRENAME(debug)
#define yypact                       YYRENAME(pact)
#define yyr1                         YYRENAME(r1)
#define yyr2                         YYRENAME(r2)
#define yydef                        YYRENAME(def)
#define yychk                        YYRENAME(chk)
#define yypgo                        YYRENAME(pgo)
#define yyact                        YYRENAME(act)
#define yyexca                       YYRENAME(exca)
#define yyerrflag                    YYRENAME(errflag)
#define yynerrs                      YYRENAME(nerrs)
#define yyps                         YYRENAME(ps)
#define yypv                         YYRENAME(pv)
#define yys                          YYRENAME(s)
#define yyss                         YYRENAME(ss)
#define yy_yys                       YYRENAME(_yys)
#define yystate                      YYRENAME(state)
#define yytmp                        YYRENAME(tmp)
#define yyv                          YYRENAME(v)
#define yy_yyv                       YYRENAME(_yyv)
#define yyval                        YYRENAME(val)
#define yyreds                       YYRENAME(reds)
#define yytoks                       YYRENAME(toks)
#define yylhs                        YYRENAME(lhs)
#define yylen                        YYRENAME(len)
#define yydefred                     YYRENAME(defred)
#define yydgoto                      YYRENAME(dgoto)
#define yysindex                     YYRENAME(sindex)
#define yyrindex                     YYRENAME(rindex)
#define yygindex                     YYRENAME(gindex)
#define yytable                      YYRENAME(table)
#define yycheck                      YYRENAME(check)
#define yyname                       YYRENAME(name)
#define yyrule                       YYRENAME(rule)
#endif

#endif /* CONFIGPRIV_H */
