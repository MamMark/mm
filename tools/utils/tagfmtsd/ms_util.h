/* $Id: ms_util.h,v 1.1 2006/07/08 06:47:14 cire Exp $
 *
 * ms_util.h - Mass Storage Interface - common utility routines
 * Copyright 2006, Eric B. Decker
 * Mam-Mark Project
 */

#ifndef _MS_UTIL_H
#define _MS_UTIL_H

#include <fs_loc.h>

extern int msu_blk_empty(uint8_t *buf);
extern char *msu_check_string(int d);
extern int msu_check_fs_loc(fs_loc_t *fsl);

#endif /* _MS_UTIL_H */
