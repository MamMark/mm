/* $Id: util.h,v 1.11 2006/07/05 06:09:25 cire Exp $ */
/*
 * util.h - misc utility routines
 * Copyright 2006, Eric B. Decker
 * Mam-Mark Project
 */

#ifndef _UTIL_H
#define _UTIL_H

extern void putstr(const char *str);
extern bool_t hex_2_ui16(uint8_t **hexstr, uint16_t *hexp);

#endif	/* _UTIL_H */
