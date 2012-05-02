/*
 * ms_unix.c - Mass Storage Interface - Unix version
 * Copyright 2006, 2010, Eric B. Decker
 * Mam-Mark Project
 *
 * Low level interface for Unix based boxes.
 * Tested on Linux and Mac OS X.
 *
 * Sep 2010, added support for Panic0 (sector 2) block.
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
#include "ms_loc.h"

static int fd = -1;

#if defined(__APPLE__)
#define loff_t		off_t
#define lseek64		lseek
#elif defined(__linux__)
extern __off64_t lseek64(int __fd, __off64_t __offset, int __whence);
#endif


ms_control_t msc;			/* mass storage control */
panic0_hdr_t p0c;			/* panic0 control */
ms_handle_t ms_handles[MS_NUM_BUFS];


extern int verbose;
extern int debug;

int
check_panic0_values(panic0_hdr_t *p) {
  int rtn;

  rtn = 0;
  if (msc.panic_start != p->panic_start) {
    fprintf(stderr, "*** panic0 mismatch: (start) %lx/%lx\n",
	    msc.panic_start, p->panic_start);
    rtn = 1;
  }
  if (msc.panic_end != p->panic_end) {
    fprintf(stderr, "*** panic0 mismatch: (end) %lx/%lx\n",
	    msc.panic_end, p->panic_end);
    rtn = 1;
  }
  return rtn;
}


ms_rtn
ms_init(char *device_name) {
    dblk_loc_t *dbl;
    panic0_hdr_t *php;
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
    msc.panic0_blk = 0;			/* indicates not found */
    p0c.panic_nxt  = 0;

    dp = ms_handles[0].buf;
    if (verbose || debug)
      fprintf(stderr, "*** reading MBR (sector 0)\n");
    ms_read_blk_fail(0, dp);

    dbl = (void *) dp + DBLK_LOC_OFFSET;
    empty = msu_check_dblk_loc(dbl);
    fprintf(stderr, "dblk_loc:  %s (%d)\n", msu_check_string(empty), empty);
    if (empty)
      return(MS_OK);

    msc.panic_start  = CF_LE_32(dbl->panic_start);
    msc.panic_end    = CF_LE_32(dbl->panic_end);
    msc.config_start = CF_LE_32(dbl->config_start);
    msc.config_end   = CF_LE_32(dbl->config_end);
    msc.dblk_start   = CF_LE_32(dbl->dblk_start);
    msc.dblk_end     = CF_LE_32(dbl->dblk_end);

    /*
     * see if there is a valid panic0 block.  The data in the block
     * must match the panic data in the dblock locator for panic.
     * Otherwise flag no panic block.
     */
    if (verbose || debug)
      fprintf(stderr, "*** reading PANIC0 (sector %lu)\n", PANIC0_SECTOR);
    ms_read_blk_fail(PANIC0_SECTOR, dp);
    php = (void *) dp;
    empty = msu_check_panic0_blk(php);
    fprintf(stderr, "panic0:    %s (%d)\n", msu_check_string(empty), empty);

    if (empty == 0) {
      /*
       * Only check the Panic0 block if we think it is present.
       *
       * the PANIC0 block information should agree with what is
       * in the dblk.  Otherwise bitch and flag the panic0 block
       * as not being present.  This will force a rewrite.
       */
      p0c.sig_a       = CF_LE_32(php->sig_a);
      p0c.panic_start = CF_LE_32(php->panic_start);
      p0c.panic_nxt   = CF_LE_32(php->panic_nxt);
      p0c.panic_end   = CF_LE_32(php->panic_end);
      p0c.fubar       = CF_LE_32(php->fubar);
      p0c.sig_b       = CF_LE_32(php->sig_b);
      p0c.chksum      = CF_LE_32(php->chksum);
      empty = check_panic0_values(&p0c);
      if (!empty)
	msc.panic0_blk  = PANIC0_SECTOR;	/* flag it as being present */
      else
	msc.panic0_blk = 0;
    }

    /*
     * Scan the rest of the dblk (using binary search) looking
     * for where the next block will start.  ie.  look for 1st
     * empty sector.
     */
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
    if (verbose || debug) {
      fprintf(stderr, "dblk_loc:  p:   s: %-8lx   e: %-8lx\n",
	      msc.panic_start, msc.panic_end);
      fprintf(stderr, "           c:   s: %-8lx   e: %-8lx\n",
	      msc.config_start, msc.config_end);
      fprintf(stderr, "           d:   s: %-8lx   e: %-8lx   n: %-8lx\n",
		msc.dblk_start, msc.dblk_end, msc.dblk_nxt);
      if (msc.dblk_nxt == 0)
	fprintf(stderr, "*** dblk_nxt not set ***\n");
      fprintf(stderr, "panic0:    p:   s: %-8lx   e: %-8lx   n: %-8lx\n",
	      p0c.panic_start, p0c.panic_end, p0c.panic_nxt);
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
