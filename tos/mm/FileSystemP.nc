/*
 * Copyright (c) 2017, Eric B. Decker
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

#include <fs_loc.h>
#include <sd.h>
#include <panic.h>
#include <platform_panic.h>

/*
 * See fs_loc.h for definitions of FS_LOC to which region
 * we are talking about.
 */

typedef enum {
  FSS_IDLE = 0,				/* doing nothing       */
  FSS_ZERO_REQ,				/* resource requested  */
  FSS_ZERO,				/* reading block zero  */
  FSS_ERASE_REQ,			/* resource requested  */
  FSS_ERASE,                            /* working on an erase */
} fs_state_t;


#define FS_ENABLE_ERASE               /* don't enable yet, doesn't work yet */


#ifndef PANIC_FS
enum {
  __pcode_fs = unique(UQ_PANIC_SUBSYS)
};

#define PANIC_FS __pcode_fs
#endif


module FileSystemP {
  provides {
    interface Boot       as Booted;     /* outgoing booted signal */
    interface FileSystem as FS;
  }
  uses {
    interface Boot;			/* incoming booted signal */
    interface SDread;
    interface SDerase;
    interface SSWrite  as SSW;
    interface Resource as SDResource;
    interface SDsa;
    interface Panic;
  }
}

implementation {

  fs_loc_t     fs_loc;
  fs_state_t   fs_state;
  uint8_t     *fs_buf;
  uint8_t      fs_which;

  void fs_panic(uint8_t where, parg_t arg0) {
    call Panic.panic(PANIC_FS, where, arg0, 0, 0, 0);
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


  void do_erase() {
#ifdef FS_ENABLE_ERASE
    error_t err;

    fs_state = FSS_ERASE;
    err = call SDerase.erase(fs_loc.locators[fs_which].start,
                             fs_loc.locators[fs_which].end);
    if (err)
      fs_panic(4, err);
#endif
  }


  event void Boot.booted() {
    error_t err;

    fs_state = FSS_ZERO_REQ;
    if ((err = call SDResource.request()))
      fs_panic(1, err);
    return;
  }


  command error_t FS.erase(uint8_t which) {
#ifdef FS_ENABLE_ERASE
    error_t err;

    if (fs_state != FSS_IDLE || which >= FS_LOC_MAX)
      call Panic.panic(PANIC_FS, 8, fs_state, which, 0, 0);

    fs_which = which;
    fs_state = FSS_ERASE_REQ;
    if (call SDResource.isOwner()) {
      do_erase();
      return SUCCESS;
    }
    err = call SDResource.request();
    if (err)
      fs_panic(9, err);
    return err;
#else
    return FAIL;
#endif
  }


  async command uint32_t FS.area_start(uint8_t which) {
    if (which < FS_LOC_MAX)
      return fs_loc.locators[which].start;
    fs_panic(7, which);
    return 0;
  }


  async command uint32_t FS.area_end(uint8_t which) {
    if (which < FS_LOC_MAX)
      return fs_loc.locators[which].end;
    fs_panic(8, which);
    return 0;
  }


  error_t get_locator(uint8_t * buf) {
    fs_loc_t *fsl;
    error_t   err;

    fsl = (void *) (buf + FS_LOC_OFFSET);
    err = check_fs_loc(fsl);
    if (err) return err;
    memcpy(&fs_loc, fsl, sizeof(fs_loc_t));
    return SUCCESS;
  }


  async command error_t FS.reload_locator_sa(uint8_t * buf) {
    error_t err;

    if (!call SDsa.inSA()) {
      err = call SDsa.reset();
      if (err) return err;
    }
    call SDsa.read(0, buf);
    err = get_locator(buf);
    return err;
  }


  event void SDResource.granted() {
    error_t err;

    switch (fs_state) {
      default:
        fs_panic(2, fs_state);
        return;

      case FSS_ZERO_REQ:
        fs_state = FSS_ZERO;
        if ((err = call SDread.read(0, fs_buf)))
          fs_panic(3, err);
        return;

      case FSS_ERASE_REQ:
        do_erase();
        return;
    }
  }


  event void SDread.readDone(uint32_t blk_id, uint8_t *read_buf, error_t err) {
    uint8_t  *dp;

    dp = fs_buf;
    if (err || dp == NULL || dp != read_buf)
      call Panic.panic(PANIC_FS, 4, err, (parg_t) dp, (parg_t) read_buf, 0);

    if (fs_state != FSS_ZERO)
      fs_panic(5, fs_state);

    err = get_locator(dp);
    if (err)
      fs_panic(6, err);
    fs_state = FSS_IDLE;

    /*
     * signal Booted first, then release the SD
     *
     * If the next module in the sequenced boot chain wants to
     * use the SD it will issue a request, which will queue them up.
     * Then when we release, it will get the SD without powering the
     * SD down.
     *
     * We may also be doing an Erase, in which case our state will no
     * longer be IDLE.  Only release if IDLE.
     */
    signal Booted.booted();
    if (fs_state == FSS_IDLE)
      call SDResource.release();
  }


  event void SDerase.eraseDone(uint32_t blk_start, uint32_t blk_end, error_t err) {
#ifdef FS_ENABLE_ERASE
    if (err || fs_state != FSS_ERASE) {
      call Panic.panic(PANIC_FS, 4, err, fs_state, 0, 0);
      return;
    }
    fs_state = FSS_IDLE;
    signal FS.eraseDone(fs_which);
    call SDResource.release();
#endif
  }


  async event void Panic.hook() { }
}
