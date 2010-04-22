/*
 * Copyright (c) 2010 - Eric B. Decker, Carl Davis
 * All rights reserved.
 *
 * FileSystem.nc - simple raw area file system based on
 * contiguous blocks of a FAT32 filesystem.
 *
 * Block 0 of the SD is the MBR.  If the filesystem is
 * bootable then most of this block (512 bytes) is code
 * that boot straps the system.  The SD card we are using
 * is not bootable.  So we lay a record down in the middle
 * of the MBR identified by majik numbers that tells us
 * the absolute block numbers of the data areas.  These
 * areas have been built by special tools that allocate
 * according to FAT rules files that encompass these regions.
 * That way the actual data files can be accessed directly
 * from any system that understands the FAT filesystem.  No
 * special tools are needed.  This greatly eases the accessibility
 * of the resultant data on Winbloz machines (which unfortunately
 * need to be supported for post processing data).
 */

#include "dblk_loc.h"

/*
 * These macros are used to ConvertFrom_LittleEndian to the native
 * format of the machine this code is running on.  The Data Block
 * Locator (the block of information in the MBR that tells us where
 * our data areas live) is written in little endian order because most
 * machines in existence (thanks Intel) are little endian.
 *
 * The MSP430 is little endian so these macros do nothing.  If a machine
 * is big endian they would have to do byte swapping.
 */

#define CF_LE_16(v) (v)
#define CF_LE_32(v) (v)
#define CT_LE_16(v) (v)
#define CT_LE_32(v) (v)

uint32_t w_t0, w_diff;

#ifdef ENABLE_ERASE
#ifdef ALWAYS_ERASE
bool     do_erase = 1;
#else
bool     do_erase;
#endif
uint32_t erase_start;
uint32_t erase_end;
#endif

module FileSystemP {
  provides {
    interface Init;
    interface Boot as OutBoot;
//    interface ResourceConfigure;
  }
  uses {
    interface Boot;
    interface SDreset;
    interface SDread;
    interface SDerase;
    interface Hpl_MM_hw as HW;
    interface Resource as WriteResource;
    interface Resource as ReadResource;
//    interface ResourceConfigure as SpiResourceConfigure;
    interface Panic;
    interface LocalTime<TMilli>;
    interface Trace;
    interface LogEvent;
  }
}
  
implementation {

init

    ssc.panic_start = ssc.panic_end = 0;
    ssc.config_start= ssc.config_end = 0;
    ssc.dblk_start  = ssc.dblk_end = 0;
    dblk_nxt        = 0;

*****

  void ss_boot_start() {
    call SDreset.reset();
  }

  error_t ss_boot_finish() {
    error_t err;
    uint8_t *dp;
    dblk_loc_t *dbl;
    uint32_t   lower, blk, upper;
    bool empty;

//    err = call SDreset.reset();
//    if (err) {
//      ss_panic(14, err);
//      return err;
//    }

    dp = ssw_p[0]->buf;
    if ((err = read_blk_fail(0, dp)))
      return err;

    dbl = (void *) ((uint8_t *) dp + DBLK_LOC_OFFSET);

#ifdef notdef
    if (do_test)
      sd_display_card(dp);
#endif

    if (check_dblk_loc(dbl)) {
      ss_panic(15, -1);
      return FAIL;
    }

    ssc.panic_start  = CF_LE_32(dbl->panic_start);
    ssc.panic_end    = CF_LE_32(dbl->panic_end);
    ssc.config_start = CF_LE_32(dbl->config_start);
    ssc.config_end   = CF_LE_32(dbl->config_end);
    ssc.dblk_start   = CF_LE_32(dbl->dblk_start);
    ssc.dblk_end     = CF_LE_32(dbl->dblk_end);

#ifdef ENABLE_ERASE
    if (do_erase) {
      erase_start = ssc.dblk_start;
      erase_end   = ssc.dblk_end;
      nop();
      call SDerase.erase(erase_start, erase_end);
    }
#endif
    if ((err = read_blk_fail(ssc.dblk_start, dp))) {
      ss_panic(16, -1);
      return err;
    }

    if (blk_empty(dp)) {
      ssc.dblk_nxt = ssc.dblk_start;
      return SUCCESS;
    }

    lower = ssc.dblk_start;
    upper = ssc.dblk_end;
    empty = 0; blk = 0;

    while (lower < upper) {
      blk = (upper - lower)/2 + lower;
      if (blk == lower)
	blk = lower = upper;
      if ((err = read_blk_fail(blk, dp)))
	return err;
      if (blk_empty(dp)) {
	upper = blk;
	empty = 1;
      } else {
	lower = blk;
	empty = 0;
      }
    }

#ifdef notdef
    if (do_test) {
      ssc.dblk_nxt = ssc.dblk_start;
      ss_test();
    }
#endif

    /* for now force to always hit the start. */
//    empty = 1; blk = ssc.dblk_start;

    if (empty) {
      ssc.dblk_nxt = blk;
      return SUCCESS;
    }

    ss_panic(17, -1);
    return FAIL;
  }


  event void SDreset.resetDone(error_t error) {
    ss_boot_finish();
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


  /*
   * check_dblk_loc
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

  uint16_t check_dblk_loc(dblk_loc_t *dbl) {
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


  event void Boot.booted() {
    call SSWriter.start(NULL);
#ifdef TEST_READER
    call SSReader.start(NULL);
#endif



    /*
     * call the system to arbritrate and configure the SPI
     * we use the default configuration for now which matches
     * what we need.
     */
    
    call WriteResource.request();

    /*
     * First start up and read in control blocks.
     * Then signal we have booted.
     */
//    if ((err = ss_boot())) {
//      ss_panic(24, err);
//    }
    ss_boot_start();

    /*
     * releasing when IDLE will power the device down.
     * and set our current state to OFF.
     */
    atomic ss_state = SS_STATE_IDLE;
    call WriteResource.release();
    signal OutBoot.booted();

  }
  


  command uint32_t FS.area_start(uint8_t which) {
    switch (which) {
      default:			return 0;
      case FS_AREA_PANIC:	return ssc.panic_start;
      case FS_AREA_CONFIG:	return ssc.config_start;
      case FS_AREA_DATA:	return ssc.dblk_start;
    }
  }

  command uint32_t FS.area_end(uint8_t which) {
    switch (which) {
      default:	return 0;
      case FS_AREA_PANIC:	return ssc.panic_end;
      case FS_AREA_CONFIG:	return ssc.config_end;
      case FS_AREA_DATA:	return ssc.dblk_end;
    }
  }
