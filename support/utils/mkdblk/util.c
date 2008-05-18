/* $Id: util.c,v 1.14 2006/07/05 06:09:25 cire Exp $ */
/*
 * util.c - misc utility routines
 * Copyright 2006, Eric B. Decker
 * Mam-Mark Project
 */

#include <stdio.h>
#include <stdarg.h>
#include <assert.h>
#include <ctype.h>
#include "mm_types.h"
#include "util.h"


/* case insensitive compare of the 2 chars
 * If alphanumeric does case insensative compare
 */

bool_t
charEquals(const char c1, const char c2) {
    if (isalpha(c1) && isalpha(c2)) {
	if ((c1 | 0x20) == (c2 | 0x20))
	    return(TRUE);
	return(FALSE);
    }
    if (c1 == c2)
	return TRUE;
    return FALSE;
}


void putstr(const char *str) {
    uint8_t *ptr;

    ptr = (uint8_t *) str;
    if (!ptr) return;
    while (*ptr)
	putchar(*ptr++);
}


bool_t hex_2_ui16(uint8_t **hexstr, uint16_t *hexp) {
    uint16_t working = 0;	/* integer value of hex string */
    uint8_t *ptr;
    uint8_t newdigit;

    ptr = *hexstr;
    while(isspace(*ptr)) ptr++;
    while (isxdigit(*ptr)) {
	newdigit = *ptr - '0';
	if (newdigit > 9) newdigit -= 7;
	working = (working << 4) | (newdigit & 0xf);
	ptr++;
    }
    if (*ptr == ' ' || !*ptr) {
	*hexp = (working & 0xffff);
	*hexstr = ptr;
	return(TRUE);
    }
    *hexstr = ptr;
    return(FALSE);
}
