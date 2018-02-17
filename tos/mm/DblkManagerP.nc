/*
 * Copyright (c) 2017-2018, Eric B. Decker
 * All rights reserved.
 *
 * This program is free software: you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation, either version 3 of the License, or
 * any later version.
 *
 * This program is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU General Public License for more details.
 *
 * You should have received a copy of the GNU General Public License
 * along with this program.  If not, see <https://www.gnu.org/licenses/>.
 * See COPYING in the top level directory of this source tree.
 *
 * Contact: Eric B. Decker <cire831@gmail.com>
 */

/*
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
#include <sd.h>

typedef enum {
  DMS_IDLE = 0,                         /* doing nothing */
  DMS_REQUEST,                          /* resource requested */
  DMS_START,                            /* read first block, chk empty */
  DMS_SCAN,                             /* scanning for 1st blank */
} dm_state_t;


#ifndef PANIC_DM
enum {
  __pcode_dm = unique(UQ_PANIC_SUBSYS)
};

#define PANIC_DM __pcode_dm
#endif


module DblkManagerP {
  provides {
    interface Boot        as Booted;    /* signals OutBoot */
    interface DblkManager;
  }
  uses {
    interface Boot;                     /* incoming boot signal */
    interface FileSystem;
    interface SDread;
    interface SDraw;
    interface SSWrite as SSW;
    interface Resource as SDResource;
    interface Panic;
  }
}

implementation {

#define DM_SIG 0x55422455

  norace struct {
    uint32_t dm_sig_a;

    /*
     * dblk_lower is where the directory lives.
     * data starts at lower+1 when that sector has been written.
     *
     * file offsets are file relative so the first record in the
     *   first data sector is at file offset 0x200 which lives in
     *   absolute sector (fo / 512) + lower.
     */
    uint32_t dblk_lower;                /* inclusive  */
                                        /* lower is where dir is */
    /* next blk_id to write */
    uint32_t dblk_nxt;                  /* 0 means full          */
    uint32_t dblk_upper;                /* inclusive  */

    /* last record number used */
    uint32_t cur_recnum;                /* current record number */
    uint32_t dm_sig_b;
  } dmc;

  dm_state_t   dm_state;
  uint8_t     *dm_buf;
  uint32_t     lower, cur_blk, upper;
  bool         do_erase = 0;


  void dm_panic(uint8_t where, parg_t p0, parg_t p1) {
    call Panic.panic(PANIC_DM, where, p0, p1, 0, 0);
  }


  event void Boot.booted() {
    error_t err;

#ifdef DBLK_ERASE_ENABLE
    /*
     * FS.erase is split phase and will grab the SD,  We will wait on the
     * erase when we request.  The FS/erase will complete and then we
     * will get the grant.
     */
    nop();                              /* BRK */
    if (do_erase) {
      do_erase = 0;
      call FileSystem.erase(FS_LOC_DBLK);
    }
#endif

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
    dmc.cur_recnum = 0;
    dm_state = DMS_REQUEST;
    if ((err = call SDResource.request()))
      dm_panic(2, err, 0);
    return;
  }


  event void SDResource.granted() {
    error_t err;

    nop();
    nop();                              /* BRK */
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

    nop();
    nop();                              /* BRK */
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
        /* if blk is erased, dmc.dblk_nxt is already correct. */
        if (call SDraw.chk_erased(dp))
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
        empty = call SDraw.chk_erased(dp);
        if (empty)
          upper = cur_blk;
        else
          lower = cur_blk;

        if (lower >= upper) {
          /*
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

    dm_state = DMS_IDLE;

    /*
     * signal OutBoot first, then release the SD
     *
     * If the next module in the sequenced boot chain wants to
     * use the SD it will issue a request, which will queue them up.
     * Then when we release, it will get the SD without powering the
     * SD down.
     */
    nop();                              /* BRK */
    signal Booted.booted();
    call SDResource.release();
  }


  async command uint32_t DblkManager.get_dblk_low() {
    return dmc.dblk_lower;
  }


  async command uint32_t DblkManager.get_dblk_high() {
    return dmc.dblk_upper;
  }


  async command uint32_t DblkManager.get_dblk_nxt() {
    return dmc.dblk_nxt;
  }


  async command uint32_t DblkManager.dblk_nxt_offset() {
    if (dmc.dblk_nxt)
      return (dmc.dblk_nxt - dmc.dblk_lower) << SD_BLOCKSIZE_NBITS;
    return 0;
  }


  async command uint32_t DblkManager.adv_dblk_nxt() {
    atomic {
      if (dmc.dblk_nxt) {
        dmc.dblk_nxt++;
        if (dmc.dblk_nxt > dmc.dblk_upper)
          dmc.dblk_nxt = 0;
      }
    }
    return dmc.dblk_nxt;
  }


  event void FileSystem.eraseDone(uint8_t which) { }

  async event void Panic.hook() { }
}
