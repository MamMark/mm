/*
 * Copyright (c) 2017, Eric B. Decker
 * All rights reserved.
 *
 * DblkManager.nc - Simple Data Block storage.
 *
 * FileManager will tell us where the Data Area lives (start/end).  The
 * first sector is reserved for the DataManager Directory which is
 * reserved.
 *
 * On boot the DblkManager will keep track of its limits (start/end) and
 * which data block to use next.  On Boot it will use a binary search to
 * find the first empty data block within the Dblk Area.
 */

#include <panic.h>
#include <platform_panic.h>

#ifdef ENABLE_ERASE
#ifdef ALWAYS_ERASE
bool     do_erase = 1;
#else
bool     do_erase = 0;
#endif
uint32_t erase_start;
uint32_t erase_end;
#endif


typedef enum {
  DMS_IDLE = 0,				/* doing nothing */
  DMS_REQUEST,				/* resource requested */
  DMS_START,				/* read first block, chk empty */
  DMS_SCAN,				/* scanning for 1st blank */
} dm_state_t;


#ifndef PANIC_DM
enum {
  __pcode_dm = unique(UQ_PANIC_SUBSYS)
};

#define PANIC_DM __pcode_fs
#endif


module DblkManagerP {
  provides {
    interface Boot        as Booted;    /* signals OutBoot */
    interface DblkManager;
  }
  uses {
    interface Boot;			/* incoming boot signal */
    interface FileSystem;
    interface SDread;
    interface SSWrite as SSW;
    interface Resource as SDResource;
    interface Panic;

#ifdef ENABLE_ERASE
    interface SDerase;
#endif

  }
}

implementation {

#define DM_SIG 0x5542

  struct {
    uint16_t dm_sig_a;
    uint32_t dblk_lower;                /* inclusive  */
    uint32_t dblk_nxt;                  /* 0 - oht oh */
    uint32_t dblk_upper;                /* inclusive  */
    uint16_t dm_sig_b;
  } dmc;

  dm_state_t   dm_state;
  uint8_t     *dm_buf;
  uint32_t     lower, cur_blk, upper;


  void dm_panic(uint8_t where, parg_t p0, parg_t p1) {
    call Panic.panic(PANIC_DM, where, p0, p1, 0, 0);
  }


  /*
   * blk_empty
   *
   * check if a Stream storage data block is empty.
   * Currently, an empty (erased SD data block) looks like
   * it is zeroed.  So we look for all data being zero.
   */

  int blk_empty(uint8_t *buf) {
    uint16_t i;
    uint16_t *ptr;

    ptr = (void *) buf;
    for (i = 0; i < SD_BLOCKSIZE/2; i++)
      if (ptr[i])
	return(0);
    return(1);
  }


  event void Boot.booted() {
    error_t err;

    lower = call FileSystem.area_start(FS_LOC_DBLK);
    upper = call FileSystem.area_end(FS_LOC_DBLK);
    if (!lower || !upper || upper < lower) {
      dm_panic(1, lower, upper);
      return;
    }
    dmc.dm_sig_a = dmc.dm_sig_b = DM_SIG;

    /* first sector is dblk directory, reserved */
    dmc.dblk_lower = lower;
    dmc.dblk_nxt   = lower + 1;
    dmc.dblk_upper = upper;
    dm_state = DMS_REQUEST;
    if ((err = call SDResource.request()))
      dm_panic(2, err, 0);
    return;
  }


  event void SDResource.granted() {
    error_t err;

    if (dm_state != DMS_REQUEST) {
      dm_panic(2, dm_state, 0);
      return;
    }

    dm_state = DMS_START;
    dm_buf = call SSW.get_temp_buf();
    if (!dm_buf) {
      dm_panic(3, (parg_t) dm_buf, 0);
      return;
    }
    if ((err = call SDread.read(dmc.dblk_nxt, dm_buf))) {
      dm_panic(4, err, 0);
      return;
    }
  }


  event void SDread.readDone(uint32_t blk_id, uint8_t *read_buf, error_t err) {
    uint8_t    *dp;
    bool        empty;

    dp = dm_buf;
    if (err || dp == NULL || dp != read_buf) {
      call Panic.panic(PANIC_DM, 5, err, (parg_t) dp, (parg_t) read_buf, 0);
      return;
    }

    switch(dm_state) {
      default:
        dm_panic(6, dm_state, 0);
        return;

      case DMS_START:
        /* if blk is empty, dmc.dblk_nxt is already correct. */
	if (blk_empty(dp))
	  break;

	lower = dmc.dblk_nxt;
	upper = dmc.dblk_upper;

	cur_blk = (upper - lower)/2 + lower;
	if (cur_blk == lower)
	  cur_blk = lower = upper;

	dm_state = DMS_SCAN;
	if ((err = call SDread.read(cur_blk, dp)))
	  dm_panic(7, err, 0);
	return;

      case DMS_SCAN:
	empty = blk_empty(dp);
	if (empty)
	  upper = cur_blk;
	else
	  lower = cur_blk;

	if (lower >= upper) {
	  /*
	   * we've looked at all the blocks.  Check the state of the last block looked at
	   * if empty we be good.  Otherwise no available storage.
	   */
	  if (empty) {
	    dmc.dblk_nxt = cur_blk;
	    break;              /* break out of switch, we be done */
	  }
	  dm_panic(8, (parg_t) cur_blk, 0);
	  return;
	}

	/*
	 * haven't looked at all the blocks.  try again
	 */
	cur_blk = (upper - lower)/2 + lower;
	if (cur_blk == lower)
	  cur_blk = lower = upper;
	if ((err = call SDread.read(cur_blk, dp)))
	  dm_panic(10, err, 0);
	return;
    }


#ifdef ENABLE_ERASE
    if (do_erase) {
      erase_start = dmc.dblk_lower;
      erase_end   = dmc.dblk_upper;
      nop();
      call SDerase.erase(erase_start, erase_end);
      return;
    }
#endif

    dm_state = DMS_IDLE;

    /*
     * signal OutBoot first, then release the SD
     *
     * If the next module in the sequenced boot chain wants to
     * use the SD it will issue a request, which will queue them up.
     * Then when we release, it will get the SD without powering the
     * SD down.
     */
    signal Booted.booted();
    call SDResource.release();
  }


#ifdef ENABLE_ERASE
  event void SDerase.eraseDone(uint32_t blk_start, uint32_t blk_end, error_t error) {
    dm_state = DMS_IDLE;
    dmc.dblk_nxt = dmc.dblk_lower + 1;

    signal Booted.booted();
    call SDResource.release();
  }
#endif


  command uint32_t DblkManager.get_nxt_blk() {
    return dmc.dblk_nxt;
  }


  command uint32_t DblkManager.adv_nxt_blk() {
    if (dmc.dblk_nxt) {
      dmc.dblk_nxt++;
      if (dmc.dblk_nxt > dmc.dblk_upper)
	dmc.dblk_nxt = 0;
    }
    return dmc.dblk_nxt;
  }

  async event void Panic.hook() { }
}
