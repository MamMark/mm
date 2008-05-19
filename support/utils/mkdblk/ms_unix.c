/* $Id: ms_unix.c,v 1.22 2007/07/22 17:49:45 cire Exp $ */
/*
 * ms_linux.c - Mass Storage Interface - Unix version
 * Copyright 2006, Eric B. Decker
 * Mam-Mark Project
 *
 * Low level interface for testing on Unix.
 * Tested on Linux and Mac OS X.
 */


#include "mm_types.h"
#include "mm_byteswap.h"

#include <stdio.h>
#include <stdlib.h>
#include <assert.h>
#include <errno.h>
#include <fcntl.h>
#include <string.h>
#include <unistd.h>

#include "ms.h"
#include "ms_util.h"
#include "dblk_loc.h"

static int fd = -1;

#if defined(__APPLE__)
#define loff_t		off_t
#define lseek64		lseek
#elif defined(__linux__)
extern __off64_t lseek64(int __fd, __off64_t __offset, int __whence);
#endif


ms_control_t msc;
ms_handle_t ms_handles[MS_NUM_BUFS];


extern int verbose;

ms_rtn
ms_init(char *device_name) {
    dblk_loc_t *dbl;
    uint32_t   blk, lower, upper;
    int empty;
    uint8_t *dp;

    assert(device_name);
    fd = open(device_name, O_RDWR);
    if (fd < 0) {
	fprintf(stderr, "ms_init: open fail: %s, %s (%d)\n",
		device_name, strerror(errno), errno);
	return(MS_INTERNAL);
    }

    msc.panic_start = msc.panic_end = 0;
    msc.config_start = msc.config_end = 0;
    msc.dblk_start = msc.dblk_end = 0;
    msc.dblk_nxt = 0;
    dp = ms_handles[0].buf;
    ms_read_blk_fail(0, dp);

    dbl = (void *) dp + DBLK_LOC_OFFSET;
    empty = msu_check_dblk_loc(dbl);
    if (empty) {
	if (verbose)
	    fprintf(stderr, "No dblk locator: %s\n", empty == 2 ? "checksum failure" : "not present");
	return(MS_OK);
    }

    msc.panic_start  = CF_LE_32(dbl->panic_start);
    msc.panic_end    = CF_LE_32(dbl->panic_end);
    msc.config_start = CF_LE_32(dbl->config_start);
    msc.config_end   = CF_LE_32(dbl->config_end);
    msc.dblk_start   = CF_LE_32(dbl->dblk_start);
    msc.dblk_end     = CF_LE_32(dbl->dblk_end);

    ms_read_blk_fail(msc.dblk_start, dp);
    if (msu_blk_empty(dp)) {
	msc.dblk_nxt = msc.dblk_start;
	return(MS_OK);
    }
    lower = msc.dblk_start;
    upper = msc.dblk_end;
    empty = 0;
    while (lower != upper) {
	blk = (upper - lower)/2 + lower;
	if (blk == lower)
	    blk = lower = upper;
	ms_read_blk_fail(blk, dp);
	if (msu_blk_empty(dp)) {
	    upper = blk;
	    empty = 1;
	} else {
	    lower = blk;
	    empty = 0;
	}
    }
    if (empty)
	msc.dblk_nxt = blk;
    if (verbose) {
	fprintf(stderr, "dblk_loc:  panic:  s: 0x%lx  e: 0x%lx  cfg s: 0x%lx  e: 0x%lx,  dblk s: 0x%lx  e: 0x%lx,  nxt: 0x%lx\n",
		msc.panic_start, msc.panic_end, msc.config_start, msc.config_end,
		msc.dblk_start, msc.dblk_end, msc.dblk_nxt);
	if (msc.dblk_nxt == 0)
	    fprintf(stderr, "*** dblk_nxt not set ***\n");
    }
    return(MS_OK);
}


ms_rtn
ms_read_blk(uint32_t blk_id, void *buf) {
    loff_t off, pos;
    int got;

    off = blk_id * MS_BLOCK_SIZE;
    pos = lseek64(fd, off, SEEK_SET);
    if (pos == -1) {
	fprintf(stderr, "ms_read_blk: seek fail: %s (%d)\n",
		strerror(errno), errno);
	return(MS_READ_FAIL);
    }
    got = read(fd, buf, MS_BLOCK_SIZE);
    if (got == -1) {
	fprintf(stderr, "ms_read_blk: read fail: %s (%d)\n",
		strerror(errno), errno);
	return(MS_READ_FAIL);
    }
    if (got != MS_BLOCK_SIZE) {
	fprintf(stderr, "ms_read_blk: read too short, req: %d, got: %d\n",
		MS_BLOCK_SIZE, got);
	return(MS_READ_TOO_SHORT);
    }
    return(MS_OK);
}


ms_rtn
ms_read_blk_fail(uint32_t blk_id, void *buf) {
    ms_rtn err;

    err = ms_read_blk(blk_id, buf);
    if (err) {
      fprintf(stderr, "*** ms_read_blk fail: %d\n", err);
      exit(1);
    }
    return(err);
}

    
ms_rtn
ms_read8(uint32_t blk_id, void *buf) {
    loff_t off, pos;
    int got;

    off = blk_id * MS_BLOCK_SIZE;
    pos = lseek64(fd, off, SEEK_SET);
    if (pos == -1) {
	fprintf(stderr, "ms_read_blk: seek fail: %s (%d)\n",
		strerror(errno), errno);
	return(MS_READ_FAIL);
    }
    got = read(fd, buf, 8);
    if (got == -1) {
	fprintf(stderr, "ms_read4: read fail: %s (%d)\n",
		strerror(errno), errno);
	return(MS_READ_FAIL);
    }
    if (got != MS_BLOCK_SIZE) {
	fprintf(stderr, "ms_read4: read too short, req: %d, got: %d\n",
		8, got);
	return(MS_READ_TOO_SHORT);
    }
    return(MS_OK);
}

    
ms_rtn
ms_write_blk(uint32_t blk_id, void *buf) {
    loff_t off, pos;
    int wrote;

    off = blk_id * MS_BLOCK_SIZE;
    pos = lseek64(fd, off, SEEK_SET);
    if (pos == -1) {
	fprintf(stderr, "ms_write_blk: seek fail: %s (%d)\n",
		strerror(errno), errno);
	return(MS_WRITE_FAIL);
    }
    wrote = write(fd, buf, MS_BLOCK_SIZE);
    if (wrote == -1) {
	fprintf(stderr, "ms_write_blk: write fail: %s (%d)\n",
		strerror(errno), errno);
	return(MS_WRITE_FAIL);
    }
    if (wrote != MS_BLOCK_SIZE) {
	fprintf(stderr, "ms_write_blk: write too short, req: %d, wrote: %d\n",
		MS_BLOCK_SIZE, wrote);
	return(MS_WRITE_TOO_SHORT);
    }
    return(MS_OK);
}


char *
ms_dsp_err(ms_rtn err) {
    switch (err) {
      case MS_OK:		return("ok");
      case MS_INTERNAL:		return("internal");
      case MS_READ_FAIL:	return("read fail");
      case MS_READ_TOO_SHORT:	return("read too short");
      case MS_WRITE_FAIL:	return("write fail");
      case MS_WRITE_TOO_SHORT:	return("write too short");
    }
    return("unknown");
}
