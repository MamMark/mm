/* $Id: ms_util.h,v 1.1 2006/07/08 06:47:14 cire Exp $
 *
 * ms_util.h - Mass Storage Interface - common utility routines
 * Copyright 2006, Eric B. Decker
 * Mam-Mark Project
 */

#ifndef _MS_UTIL_H
#define _MS_UTIL_H

#include "dblk_loc.h"

extern int msu_blk_empty(uint8_t *buf);
extern int msu_check_dblk_loc(dblk_loc_t *dbl);

#endif /* _MS_UTIL_H */
