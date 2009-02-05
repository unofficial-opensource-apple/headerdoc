/*
 * Copyright (c) 2002-2004 Apple Computer, Inc. All rights reserved.
 *
 * @APPLE_LICENSE_HEADER_START@
 * 
 * This file contains Original Code and/or Modifications of Original Code
 * as defined in and that are subject to the Apple Public Source License
 * Version 2.0 (the 'License'). You may not use this file except in
 * compliance with the License. Please obtain a copy of the License at
 * http://www.opensource.apple.com/apsl/ and read it before using this
 * file.
 * 
 * The Original Code and all software distributed under the License are
 * distributed on an 'AS IS' basis, WITHOUT WARRANTY OF ANY KIND, EITHER
 * EXPRESS OR IMPLIED, AND APPLE HEREBY DISCLAIMS ALL SUCH WARRANTIES,
 * INCLUDING WITHOUT LIMITATION, ANY WARRANTIES OF MERCHANTABILITY,
 * FITNESS FOR A PARTICULAR PURPOSE, QUIET ENJOYMENT OR NON-INFRINGEMENT.
 * Please see the License for the specific language governing rights and
 * limitations under the License.
 * 
 * @APPLE_LICENSE_HEADER_END@
 */

#include <unistd.h>
#include <stdlib.h>
#include <stdio.h>
#include <sys/dirent.h>
#include <libxml/parser.h>
#include <libxml/tree.h>

typedef struct usage {
    char *flag;
    char *arg;
    char *desc;
    char *functype;
    char *funcname;
    struct usage *funcargs;
    int optional;
    struct usage *next;
} *usage_t;

usage_t usage_head = NULL, usage_tail = NULL;
int seen_name = 0;

char *striplines(char *line);

#define MAX(a, b) ((a<b) ? b : a)

void xml2man(xmlNode *root, char *output_filename, int append_section_number);
void parseUsage(xmlNode *node);

void strip_dotmxml(char *filename)
{
    char *last = &filename[strlen(filename)-5];
    if (!strcmp(last, ".mxml")) *last = '\0';
}

int main(int argc, char *argv[])
{
    xmlDocPtr dp;
    xmlNode *root;
    char output_filename[MAXNAMLEN];
    int append_section_number;

    if (argc < 1) {
	fprintf(stderr, "xml2man: No arguments given.\n");
	exit(-1);
    }

    LIBXML_TEST_VERSION;

    if (argc >= 2) {
	if (!(dp = xmlParseFile(argv[1]))) {
	    perror(argv[0]);
	    fprintf(stderr, "xml2man: could not parse XML file\n");
	    exit(-1);
	}
    } else {
	char *buf = malloc(1024 * sizeof(char));
	int bufpos = 0;
	int bufsize = 1024;
	while (1) {
	    char line[1026]; int len;

	    if (fgets(line, 1024, stdin) == NULL) break;
	    len = strlen(line);
	    while ((bufpos + len + 2) >= bufsize) {
		bufsize *= 2;
		buf = realloc(buf, bufsize);
	    }
	    strcat(&buf[bufpos], line);
	    bufpos += len;
	}
	xmlParseMemory(buf, bufpos+1);
    }
    root = xmlDocGetRootElement(dp);

    /* Walk the tree and convert to mdoc */
    if (argc >= 3) {
	int len = MAX(strlen(argv[2]), MAXNAMLEN-1);
	strncpy(output_filename, argv[2], len);
	output_filename[len] = '\0';
	append_section_number = 0;
    } else if (argc >= 2) {
	int len = MAX(strlen(argv[1]), MAXNAMLEN-4);
	strncpy(output_filename, argv[1], len);
	output_filename[len] = '\0';
	/* We'll append ".1" or whatever later. */
	strip_dotmxml(output_filename);
	append_section_number = 1;
    } else {
	/* We'll dump to stdout at the right time */
	output_filename[0] = 0;
	append_section_number = 0;
    }

    xml2man(root, output_filename, append_section_number);

    /* Clean up just to be polite. */
    xmlFreeDoc(dp);
    xmlCleanupParser();
}


char *textmatching(char *name, xmlNode *cur, int missing_ok);
xmlNode *nodematching(char *name, xmlNode *cur);
void writeData(FILE *fp, xmlNode *node);
void writeUsage(FILE *fp);

void xml2man(xmlNode *root, char *output_filename, int append_section_number)
{
    int section;
    xmlNode *names, *usage, *retvals, *env, *files, *examples, *diags, *errs;
    xmlNode *seeAlso, *conformingTo, *history, *bugs;
    char *docdate = "January 1, 9999";
    char *doctitle = "UNKNOWN MANPAGE";
    char *os = "";
    char *temp;
    FILE *fp;

    temp = textmatching("section", root->children, 0);

    if (temp) section = atoi(temp);
    else { fprintf(stderr, "Assuming section 1.\n"); section = 1; }

    temp = textmatching("docdate", root->children, 0);
    if (temp) docdate = temp;

    temp = textmatching("doctitle", root->children, 0);
    if (temp) doctitle = temp;

    temp = textmatching("os", root->children, 0);
    if (temp) os = temp;

    names = nodematching("names", root->children);
    usage = nodematching("usage", root->children);
    retvals = nodematching("returnvalues", root->children);
    env = nodematching("environment", root->children);
    files = nodematching("files", root->children);
    examples = nodematching("examples", root->children);
    diags = nodematching("diagnostics", root->children);
    errs = nodematching("errors", root->children);
    seeAlso = nodematching("seealso", root->children);
    conformingTo = nodematching("conformingto", root->children);
    history = nodematching("history", root->children);
    bugs = nodematching("bugs", root->children);

    if (usage) { parseUsage(usage->children); }

    // printf("section %d\n", section);
    // printf("nodes: names = 0x%x, usage = 0x%x, retvals = 0x%x, env = 0x%x,\nfiles = 0x%x, examples = 0x%x, diags = 0x%x, errs = 0x%x,\nseeAlso = 0x%x, conformingTo = 0x%x, history = 0x%x, bugs = 0x%x\n", names, usage, retvals, env, files, examples, diags, errs, seeAlso, conformingTo, history, bugs);

    /* Write everything to stdout for now */
    if (!strlen(output_filename)) {
	fp = stdout;
    } else {
	if (append_section_number) {
	    sprintf(output_filename, "%s.%d", output_filename, section);
	}
	if (fp = fopen(output_filename, "r")) {
	    fprintf(stderr, "error: file %s exists.\n", output_filename);
	    exit(-1);
	} else {
	    if (!(fp = fopen(output_filename, "w"))) {
		fprintf(stderr, "error: could not create file %s\n", output_filename);
		exit(-1);
	    }
	}
    }

    /* write preamble */
    fprintf(fp, ".\\\" Automatically generated from mdocxml\n");
    fprintf(fp, ".Dd %s\n", docdate);
    fprintf(fp, ".Dt \"%s\" %d\n", doctitle, section);
    fprintf(fp, ".Os %s\n", os);

    /* write rest of contents */
    writeData(fp, names);
    writeUsage(fp);
    writeData(fp, retvals);
    writeData(fp, env);
    writeData(fp, files);
    writeData(fp, examples);
    writeData(fp, diags);
    writeData(fp, errs);
    writeData(fp, seeAlso);
    writeData(fp, conformingTo);
    writeData(fp, history);
    writeData(fp, bugs);

    if (strlen(output_filename)) {
	fclose(fp);
    }
}

xmlNode *nodematching(char *name, xmlNode *cur)
{
    while (cur) {
	if (!cur->name) break;
	if (!strcmp(cur->name, name)) break;
	cur = cur->next;
    }

    return cur;
}

char *textmatching(char *name, xmlNode *node, int missing_ok)
{
    xmlNode *cur = nodematching(name, node);
    char *ret = NULL;

    if (!cur) {
	if (!missing_ok) {
		fprintf(stderr, "Invalid or missing contents for %s.\n", name);
	}
    } else if (cur && cur->children && cur->children->content) {
		ret = cur->children->content;
    } else if (!strcmp(name, "text")) {
		ret = cur->content;
    } else {
	fprintf(stderr, "Missing/invalid contents for %s.\n", name);
    }

    return ret;
}

enum states
{
    kGeneral = 0,
    kNames   = 1,
    kRetval  = 2,
    kMan     = 3,
    kLast    = 256
};

void writeData_sub(FILE *fp, xmlNode *node, int state, int textcontainer, int next);
void writeData(FILE *fp, xmlNode *node)
{
    writeData_sub(fp, node, 0, 0, 0);
}

void writeData_sub(FILE *fp, xmlNode *node, int state, int textcontainer, int next)
{
    int oldtextcontainer = textcontainer;
    int oldstate = state;

    char *tail = NULL;

    if (!node) return;
    if (!strcmp(node->name, "docdate")) {
	/* silently ignore */
	writeData_sub(fp, node->next, state, 0, 1);
	return;
    } else if (!strcmp(node->name, "doctitle")) {
	/* silently ignore */
	writeData_sub(fp, node->next, state, 0, 1);
	return;
    } else if (!strcmp(node->name, "section")) {
	if (state == kMan) {
		fprintf(fp, " ");
		tail = " ";
	} else {
		/* silently ignore */
		writeData_sub(fp, node->next, state, 0, 1);
		return;
	}
    } else if (!strcmp(node->name, "desc")) {
	if (state == kNames && node->children) {
		fprintf(fp, ".Nd ");
	}
	// if (!node->children) tail = "\n";
    } else if (!strcmp(node->name, "names")) {
	state = kNames;
	fprintf(fp, ".Sh NAME\n");
    } else if (!strcmp(node->name, "name")) {
	if (state == kNames) {
		if (seen_name) {
			fprintf(fp, ".Pp\n");
		}
		fprintf(fp, ".Nm ");
		textcontainer = 1;
		seen_name = 1;
	} else {
		fprintf(fp, ".Nm\n");
	}
    } else if (!strcmp(node->name, "usage")) {
	textcontainer = 0;
    } else if (!strcmp(node->name, "flag")) {
    } else if (!strcmp(node->name, "arg")) {
    } else if (!strcmp(node->name, "returnvalues")) {
	state = kRetval;
	textcontainer = 1;
	fprintf(fp, ".Sh RETURN VALUES\n");
    } else if (!strcmp(node->name, "environment")) {
	state = kRetval;
	textcontainer = 1;
	fprintf(fp, ".Sh ENVIRONMENT\n");
    } else if (!strcmp(node->name, "files")) {
	textcontainer = 0;
	fprintf(fp, ".Sh FILES\n");
	fprintf(fp, ".Bl -tag -width indent\n");
	tail = ".El\n";
    } else if (!strcmp(node->name, "file")) {
	textcontainer = 1;
	fprintf(fp, ".It Pa ");
    } else if (!strcmp(node->name, "examples")) {
	state = kRetval;
	textcontainer = 1;
	fprintf(fp, ".Sh EXAMPLES\n");
    } else if (!strcmp(node->name, "diagnostics")) {
	state = kRetval;
	textcontainer = 1;
	fprintf(fp, ".Sh DIAGNOSTICS\n");
    } else if (!strcmp(node->name, "errors")) {
	state = kRetval;
	textcontainer = 1;
	fprintf(fp, ".Sh ERRORS\n");
    } else if (!strcmp(node->name, "seealso")) {
	state = kRetval;
	textcontainer = 1;
	fprintf(fp, ".Sh SEE ALSO\n");
    } else if (!strcmp(node->name, "conformingto")) {
	state = kRetval;
	textcontainer = 1;
	fprintf(fp, ".Sh CONFORMING TO\n");
    } else if (!strcmp(node->name, "history")) {
	state = kRetval;
	textcontainer = 1;
	fprintf(fp, ".Sh HISTORY\n");
    } else if (!strcmp(node->name, "bugs")) {
	state = kRetval;
	textcontainer = 1;
	fprintf(fp, ".Sh BUGS\n");
    } else if (!strcmp(node->name, "p")) {
	tail = ".Pp\n";
    } else if (!strcmp(node->name, "blockquote")) {
	fprintf(fp, ".Bl -tag -width indent\n");
	tail = ".El\n";
    } else if (!strcmp(node->name, "tt")) {
	fprintf(fp, ".Dl ");
    } else if (!strcmp(node->name, "ul")) {
	fprintf(fp, ".Bl -bullet\n");
	tail = ".El\n";
    } else if (!strcmp(node->name, "ol")) {
	fprintf(fp, ".Bl -enum\n");
	tail = ".El\n";
    } else if (!strcmp(node->name, "li")) {
	fprintf(fp, ".It\n");
    } else if (!strcmp(node->name, "code")) {
	fprintf(fp, ".Li ");
    } else if (!strcmp(node->name, "path")) {
	fprintf(fp, ".Pa ");
    } else if (!strcmp(node->name, "function")) {
	fprintf(fp, ".Fn ");
    } else if (!strcmp(node->name, "command")) {
	/* @@@ Is this right? @@@ */
	fprintf(fp, ".Nm ");
    } else if (!strcmp(node->name, "manpage")) {
	/* Cross-reference */
	fprintf(fp, ".Xr ");
	state = kMan;
	tail = "\n";
	textcontainer = 1;
    } else if (!strcmp(node->name, "text")) {
	if (textcontainer) {
		char *stripped_text = striplines(node->content);
		if (strlen(stripped_text)) {
			fprintf(fp, "%s%s", stripped_text, (state == kMan ? "" : "\n"));
		}
	}
    } else {
	fprintf(stderr, "unknown field %s\n", node->name);
    }

    writeData_sub(fp, node->children, state, textcontainer, 1);
    textcontainer = oldtextcontainer;
    state = oldstate;
    if (tail) {
	fprintf(fp, "%s", tail);
    }
    if (next) {
	writeData_sub(fp, node->next, state, textcontainer, 1);
    }
}


void write_funcargs(FILE *fp, usage_t cur)
{
    for (; cur; cur = cur->next) {
	fprintf(fp, ".It Ar \"%s\"", cur->arg ? cur->arg : "");
	fprintf(fp, "\n%s%s", cur->desc ? cur->desc : "", cur->desc ? "\n" : "");
    }
}


char *xs(int count)
{
    static char *buffer = NULL;
    if (buffer) free(buffer);
    buffer = malloc((count+1) * sizeof(char));
    if (buffer) {
	int i;
	for (i=0; i<count; i++) buffer[i] = 'X';
    }
    buffer[count] = '\0';

    return buffer;
}


void writeUsage(FILE *fp)
{
    usage_t cur;
    int first;
    int function = 0;
    int lwc;

    /* Write SYNOPSIS section */

    fprintf(fp, ".Sh SYNOPSIS\n");

    lwc = 6;
    for (cur = usage_head; cur; cur = cur->next) {
	int len;
	len = 0;
	if (cur->flag) len += strlen(cur->flag);
	if (cur->arg) len += strlen(cur->arg);
	if (len > lwc) lwc = len;
    }
    lwc += 4;

    first = 1;
    for (cur = usage_head; cur; cur = cur->next) {
	if (cur->flag) {
		if (first) { fprintf(fp, ".Nm\n"); first = 0; }
		fprintf(fp, ".%sFl %s", (cur->optional?"Op ":""), cur->flag);
	}
	if (cur->arg) {
		if (first) { fprintf(fp, ".Nm\n"); first = 0; }
		fprintf(fp, "%sAr %s", (cur->flag?" ":"."), cur->arg);
	}
	if (cur->functype) {
		usage_t arg;
		fprintf(fp, ".Ft %s\n", cur->functype);
		fprintf(fp, ".Fn \"%s\" ", cur->funcname);
		for (arg = cur->funcargs; arg; arg = arg->next) {
			fprintf(fp, "\"%s\" ", arg->arg);
		}
		function = 1;
	}
	fprintf(fp, "\n");
    }

    /* Write OPTIONS section */

    first=1;
    for (cur = usage_head; cur; cur = cur->next) {
	if (cur->funcargs) {
		if (first) {
			fprintf(fp, ".Sh OPTIONS\n");
			first = 0;
			fprintf(fp, ".Bl -tag -width %s\n", xs(lwc));
		}
		write_funcargs(fp, cur->funcargs);
		continue;
	}
	// if (!cur->flag) continue;
	if (!cur->desc) continue;
	if (first) {
		fprintf(fp, ".Sh OPTIONS\n");
		fprintf(fp, "The available options are as follows:\n");
		fprintf(fp, ".Bl -tag -width %s\n", xs(lwc));
		first = 0;
	}
	fprintf(fp, ".It");
	if (cur->flag) { fprintf(fp, " Fl %s", cur->flag); }
	if (cur->arg) {
		fprintf(fp, " Ar \"%s\"", cur->arg);
	}
	fprintf(fp, "\n%s\n", cur->desc);
    }
    if (!first) { fprintf(fp, ".El\n"); }

}


int propval(char *name, struct _xmlAttr *prop)
{
    for (; prop; prop=prop->next) {
	if (!strcmp(prop->name, name)) {
		if (prop->children && prop->children->content) {
			return atoi(prop->children->content);
		}
	}
    }
    /* Assume 0 */
    return 0;
}


void parseUsage(xmlNode *node)
{
    usage_t flag_or_arg;

    if (!node) return;

    if (!strcmp(node->name, "text") || !strcmp(node->name, "type") ||
	!strcmp(node->name, "name")) {
	    parseUsage(node->next);
	    return;
    }

    flag_or_arg = (usage_t)malloc(sizeof(struct usage));
    if (!flag_or_arg) return;
    if (!usage_head) {
	usage_head = flag_or_arg;
	usage_tail = flag_or_arg;
    } else {
	usage_tail->next = flag_or_arg;
	usage_tail = flag_or_arg;
    }

    if (!strcmp(node->name, "arg")) {
	flag_or_arg->flag = NULL;
	flag_or_arg->arg  = textmatching("text", node->children, 0);
	flag_or_arg->desc = textmatching("desc", node->children, 0);
	flag_or_arg->optional = propval("optional", node->properties);
	flag_or_arg->functype = NULL;
	flag_or_arg->funcname = NULL;
	flag_or_arg->funcargs = NULL;
	flag_or_arg->next = NULL;
    } else if (!strcmp(node->name, "flag")) {
	flag_or_arg->flag = textmatching("text", node->children, 0);
	flag_or_arg->arg  = textmatching("arg", node->children, 1);
	flag_or_arg->desc = textmatching("desc", node->children, 0);
	flag_or_arg->optional = propval("optional", node->properties);
	flag_or_arg->functype = NULL;
	flag_or_arg->funcname = NULL;
	flag_or_arg->funcargs = NULL;
	flag_or_arg->next = NULL;
    } else if (!strcmp(node->name, "func")) {
	/* "func" */
	flag_or_arg->flag = NULL;
	flag_or_arg->arg  = NULL;
	flag_or_arg->desc = NULL;
	flag_or_arg->optional = 0;
	flag_or_arg->functype = textmatching("type", node->children, 0);
	flag_or_arg->funcname = textmatching("name", node->children, 0);
	flag_or_arg->next = NULL;
	// printf("RECURSE\n");
	parseUsage(node->children);
	// printf("RECURSEOUT\n");
	flag_or_arg->funcargs = flag_or_arg->next;
	usage_tail = flag_or_arg;
	flag_or_arg->next = NULL;
    } else {
	fprintf(stderr, "UNKNOWN NODE NAME: %s\n", node->name);
    }

    parseUsage(node->next);
}

enum stripstate
{
    kSOL = 1,
    kText = 2
};

char *striplines(char *line)
{
    static char *ptr = NULL;
    char *pos;
    char *linepos;
    int state = 0;

    if (!line) return "";
    linepos = line;

    if (ptr) free(ptr);
    ptr = malloc(strlen(line) * sizeof(char));

    state = kSOL;
    pos = ptr;
    for (pos=ptr; (*linepos); linepos++,pos++) {
	switch(state) {
		case kSOL:
			if (*linepos == ' ' || *linepos == '\n' || *linepos == '\r' ||
			    *linepos == '\t') { pos--; continue; }
		case kText:
			if (*linepos == '\n' || *linepos == '\r') {
				state = kSOL;
				*pos = ' ';
			} else {
				state = kText;
				*pos = *linepos;
			}
	}
    }
    *pos = '\0';

    // printf("LINE \"%s\" changed to \"%s\"\n", line, ptr);

    return ptr;
}

