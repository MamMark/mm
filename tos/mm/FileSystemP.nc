/*
 * Copyright (c) 2010 - Eric B. Decker, Carl Davis
 * Copyright (c) 2017, Eric B. Decker
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

#include <fs_loc.h>
#include <sd.h>
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
  FSS_IDLE = 0,				/* doing nothing */
  FSS_REQUEST,				/* resource requested */
  FSS_ZERO,				/* reading block zero */
} fs_state_t;


#ifndef PANIC_FS
enum {
  __pcode_fs = unique(UQ_PANIC_SUBSYS)
};

#define PANIC_FS __pcode_fs
#endif


module FileSystemP {
  provides {
    interface Boot as FSBooted;		/* outgoing booted signal */
    interface FileSystem as FS;
  }
  uses {
    interface Boot;			/* incoming booted signal */
    interface SDread;
    interface SSWrite as SSW;
    interface Resource as SDResource;
    interface Panic;
  }
}

implementation {

  fs_loc_t     fs_loc;
  fs_state_t   fs_state;
  uint8_t     *fs_buf;


  void fs_panic(uint8_t where, parg_t arg0) {
    call Panic.panic(PANIC_FS, where, arg0, 0, 0, 0);
  }

  void fs_panic_idle(uint8_t where, parg_t arg0) {
    call Panic.panic(PANIC_FS, where, arg0, 0, 0, 0);
    fs_state = FSS_IDLE;
  }


  /*
   * check_fs_loc
   *
   * Check the FS Locator for validity.
   *
   * First check is for the signature.  No sig, no play.
   * Second, we need the checksum to match.
   *
   * If the chksum is good, then we sum to zero.
   *
   * i: *fsl	fs locator structure pointer
   *
   * o: rtn	0  if locator valid
   *		1  if no locator found
   *		2  if locator checksum failed
   *		3  bad value in locator
   */

  uint16_t check_fs_loc(fs_loc_t *fsl) {
    uint16_t *p;
    uint16_t sum, i;

    if (fsl->loc_sig   != CF_LE_32(FS_LOC_SIG) ||
        fsl->loc_sig_a != CF_LE_32(FS_LOC_SIG))
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
      sum += CF_LE_16(p[i]);
    if (sum)
      return 2;
    return(0);
  }


  event void Boot.booted() {
    error_t err;

    fs_state = FSS_REQUEST;
    if ((err = call SDResource.request()))
      fs_panic_idle(1, err);
    return;
  }


  event void SDResource.granted() {
    error_t err;

    if (fs_state != FSS_REQUEST) {
      fs_panic_idle(2, fs_state);
      return;
    }
    fs_state = FSS_ZERO;
    fs_buf = call SSW.get_temp_buf();
    if ((err = call SDread.read(0, fs_buf))) {
      fs_panic_idle(3, err);
      return;
    }
  }


  event void SDread.readDone(uint32_t blk_id, uint8_t *read_buf, error_t err) {
    fs_loc_t *fsl;
    uint8_t  *dp;

    dp = fs_buf;
    if (err || dp == NULL || dp != read_buf) {
      call Panic.panic(PANIC_FS, 4, err, (parg_t) dp, (parg_t) read_buf, 0);
      return;
    }

    switch(fs_state) {
      default:
	  fs_panic_idle(5, fs_state);
	  return;

      case FSS_ZERO:
	fsl = (void *) ((uint8_t *) dp + FS_LOC_OFFSET);
        err = check_fs_loc(fsl);
        if (err) {
	  fs_panic_idle(6, err);
	  return;
	}

        memcpy(&fs_loc, fsl, sizeof(fs_loc_t));
        break;
    }

    fs_state = FSS_IDLE;

    /*
     * signal OutBoot first, then release the SD
     *
     * If the next module in the sequenced boot chain wants to
     * use the SD it will issue a request, which will queue them up.
     * Then when we release, it will get the SD without powering the
     * SD down.
     */
    signal FSBooted.booted();
    call SDResource.release();
  }


  command uint32_t FS.area_start(uint8_t which) {
    if (which < FS_LOC_MAX)
      return fs_loc.locators[which].start;
    fs_panic(7, which);
    return 0;
  }


  command uint32_t FS.area_end(uint8_t which) {
    if (which < FS_LOC_MAX)
      return fs_loc.locators[which].end;
    fs_panic(8, which);
    return 0;
  }

  async event void Panic.hook() { }
}
