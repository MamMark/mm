/* $Id: ms_util.c,v 1.7 2007/07/22 18:23:14 cire Exp $
 *
 * ms_util.c - Mass Storage Interface - common utility routines
 * Copyright 2006, Eric B. Decker
 * Mam-Mark Project
 */

#include "mm_types.h"
#include "mm_byteswap.h"
#include "ms.h"
#include "ms_util.h"


/*
 * msu_blk_empty
 *
 * check if a mass storage data block is empty.
 * Currently, an empty (erased SD data block) looks like
 * it is zeroed.  So we look for all data being zero.
 */

int
msu_blk_empty(uint8_t *buf) {
    uint16_t i;
    uint16_t *ptr;

    ptr = (void *) buf;
    for (i = 0; i < MS_BLOCK_SIZE/2; i++)
	if (ptr[i])
	    return(0);
//    return(1);
    return(0);
}


/*
 * msu_check_dblk_loc
 *
 * Check the Dblk Locator for validity.
 *
 * First, we look for the magic number in the majik spot
 * Second, we need the checksum to match.  Checksum is computed over
 * the entire dblk_loc structure.
 *
 * i: *dbl	dblk locator structure pointer
 *
 * o: rtn	0  if dblk valid
 *		1  if no dblk found
 *		2  if dblk checksum failed
 *		3  bad value in dblk
 */

int
msu_check_dblk_loc(dblk_loc_t *dbl) {
    uint16_t *p;
    uint16_t sum, i;

    if (dbl->sig != CT_LE_32(TAG_DBLK_SIG))
	return(1);
    if (dbl->panic_start == 0 || dbl->panic_end == 0 ||
	  dbl->config_start == 0 || dbl->config_end == 0 ||
	  dbl->dblk_start == 0 || dbl->dblk_end == 0)
	return(3);
    if (dbl->panic_start > dbl->panic_end ||
	  dbl->config_start > dbl->config_end ||
	  dbl->dblk_start > dbl->dblk_end)
	return(3);
    p = (void *) dbl;
    sum = 0;
    for (i = 0; i < DBLK_LOC_SIZE_SHORTS; i++)
	sum += CF_LE_16(p[i]);
    if (sum)
	return(2);
    return(0);
}
