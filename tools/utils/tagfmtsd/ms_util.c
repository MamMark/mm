/*
 * ms_util.c - Mass Storage Interface - common utility routines
 * Copyright 2006, 2017 Eric B. Decker
 * Mam-Mark Project
 */

#include <mm_types.h>
#include <mm_byteswap.h>
#include <ms.h>
#include <fs_loc.h>
#include <ms_util.h>


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
    return(1);
}


/*
 * msu_check_string
 *
 * return error string given error code from one of the
 * following check routines.
 */

char *
msu_check_string(int d) {
  switch (d) {
    case 0:	return "valid";
    case 1:	return "not found";
    case 2:	return "checksum error";
    case 3:	return "bad value";
    default:	return "unknown";
  }
}


/*
 * msu_check_fs_loc
 *
 * Check the file system locator block for validity.
 *
 * First, we look for the magic number in the majik spot
 * Second, we need the checksum to match.  Checksum is computed over
 * the entire fs_loc structure.
 *
 * i: *fsl	fs locator structure pointer
 *
 * o: rtn	0  if dblk valid
 *		1  if no dblk found
 *		2  if fs_loc checksum failed
 *		3  bad value in dblk
 */

int
msu_check_fs_loc(fs_loc_t *fsl) {
    uint16_t *p;
    uint16_t sum, i;

    if (fsl->loc_sig != FS_LOC_SIG || fsl->loc_sig_a != FS_LOC_SIG)
	return 1;
    for (i = 0; i < FS_LOC_MAX; i++) {
      if (!(fsl->locators[i].start) || !(fsl->locators[i].end))
        return 3;
      if ((fsl->locators[i].start  > fsl->locators[i].end))
        return 3;
    }

    p = (void *) fsl;
    i = 0;
    sum = 0;
    for (i = 0; i < FS_LOC_SIZE_SHORTS; i++)
      sum += p[i];
    if (sum)
      return 2;
    return 0;
}


/*
 * msu_check_panic0_blk
 *
 * Check the Panic0 blk for validity.
 *
 * The panic0 block contains critical information for the
 * panic subsystem.  Included information is panic_start,
 * panic_end, and panic_nxt.  This information is protected
 * by tombstones and a checksum.
 *
 * First, we look for the magic numbers in the tombstones.
 * Second, we need the checksum to match.  Checksum is computed over
 * the entire panic0_hdr structure.
 *
 * i: *php	panic0_hdr structure pointer
 *
 * o: rtn	0  if panic0_hdr valid
 *		1  if no panic0_hdr found
 *		2  if checksum failed
 *		3  illegal value detected.
 */

int
msu_check_panic0_blk(panic0_hdr_t *php) {
    uint16_t *p;
    uint16_t sum, i;

    if (php->sig_a != CT_LE_32(PANIC0_MAJIK) ||
	php->sig_b != CT_LE_32(PANIC0_MAJIK))
	return(1);
    if (php->panic_start == 0 || php->panic_end == 0)
	return(3);
    if (php->panic_start > php->panic_end ||
	php->panic_nxt < php->panic_start ||
	php->panic_nxt > php->panic_end)
      return(3);
    p = (void *) php;
    sum = 0;
    for (i = 0; i < PANIC0_SIZE_SHORTS; i++)
	sum += CF_LE_16(p[i]);
    if (sum)
	return(2);
    return(0);
}
