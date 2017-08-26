/*
 * ms.h - Mass Storage Interface (low level)
 * Copyright 2006, 2010, Eric B. Decker
 * Mam-Mark Project
 *
 * Provides a simple abstraction to the h/w.
 *
 * WARNING: This file is now only used for MKDBLK and
 * is no longer used for building a working embeded system.
 */

#ifndef _MS_H
#define _MS_H

#include <fs_loc.h>

/* needs to agree with SECTOR_SIZE and SD_BLOCKSIZE
   MS_BUF_SIZE includes CRC bytes.
   yeah it is stupid and ugly.

   MS_CRITICAL_BUFS is the number of full buffers that
   will force the MS system to take the usart h/w.
*/
#define MS_BLOCK_SIZE 512
#define MS_BUF_SIZE   514
#define MS_NUM_BUFS   4
//#define MS_CRITICAL_BUFS 3


/*
 * Erased sectors show up as zero.  Not sure if this always
 * works but we don't want to deal with erasure.  So we assume
 * that the dblk area of the flash has been initially erased.
 */


/*
 * Return codes returnable from MS layer
 */

#define MS_ID 0x10

typedef enum {
    MS_OK		= 0,
    MS_FAIL		= (MS_ID | 1),
    MS_READONLY		= (MS_ID | 2),
    MS_INTERNAL		= (MS_ID | 3),
    MS_READ_FAIL	= (MS_ID | 4),
    MS_READ_TOO_SHORT	= (MS_ID | 5),
    MS_WRITE_FAIL	= (MS_ID | 6),
    MS_WRITE_TOO_SHORT	= (MS_ID | 7),
} ms_rtn;


/*
 * extern reference to msc for unix utilities.
 */

extern fs_loc_t     loc;
extern uint32_t     msc_dblk_nxt;
extern uint32_t     msc_panic0_blk;
extern panic0_hdr_t p0c;

extern ms_rtn ms_init(char *device_name);
extern ms_rtn ms_read_blk(uint32_t blk_id, void *buf);
extern ms_rtn ms_read_blk_fail(uint32_t blk_id, void *buf);
extern ms_rtn ms_read8(uint32_t blk_id, void *buf);
extern ms_rtn ms_write_blk(uint32_t blk_id, void *buf);

extern char * ms_dsp_err(ms_rtn err);

#endif /* _MS_H */
