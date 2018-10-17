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
#include <typed_data.h>

typedef enum {
  DMS_IDLE = 0,                         /* doing nothing */
  DMS_REQUEST,                          /* resource requested */
  DMS_START,                            /* read first block, chk empty */
  DMS_SCAN,                             /* scanning for 1st blank */
  DMS_SYNC,                             /* find last sync record in valid */
  DMS_LAST_REC,                         /* find last record after last sync */
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
    interface Resync;
    interface ByteMapFile as DMF;
    interface Crc<uint8_t> as Crc8;
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

    /* search for last record */
    uint32_t   cur_offset;              // offset of current search
    uint32_t   found_offset;            // valid last record offset
    dt_header_t found_hdr;              // found record header
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
      dm_panic(3, dm_state, 0);
      return;
    }

    dm_state = DMS_START;
    dm_buf = call SSW.get_temp_buf();
    if (!dm_buf) {
      dm_panic(4, (parg_t) dm_buf, 0);
      return;
    }
    if ((err = call SDread.read(dmc.dblk_nxt, dm_buf))) {
      dm_panic(5, err, 0);
      return;
    }
  }


  bool hdr_valid(dt_header_t *hdr) {
    return TRUE;
  }

  void task dblk_last_task() {
    dt_header_t hdr;
    uint32_t    dlen = sizeof(hdr);
    error_t     err;
    bool        done = FALSE;

    if (dm_state != DMS_LAST_REC) dm_panic(12, dm_state, 0);

    while (!done && (dmc.cur_offset < call DblkManager.dblk_nxt_offset())) {
      err = call DMF.mapAll(0, (uint8_t **) &hdr, dmc.cur_offset, &dlen);
      switch (err) {
        case SUCCESS:
          if (hdr_valid(&hdr)) {
            dmc.found_offset = dmc.cur_offset;
            dmc.found_hdr = hdr;
            dmc.cur_offset += hdr.len;
          } else {
            done = TRUE;
          }
          break;

        case EBUSY:
          return;

        case EODATA:
          done = TRUE;
          break;

        default:
          dm_panic(77, dm_state, err);
      }
    }
    // now need to extract record information to be used
    dmc.found_hdr.recnum = dmc.found_hdr.recnum + 1;
    // use timestamp as candidate for current datetime

    // finally, let rest of system start run
    signal Booted.booted();
  }


  event void SDread.readDone(uint32_t blk_id, uint8_t *read_buf, error_t err) {
    uint8_t    *dp;
    bool        empty;

    nop();
    nop();                              /* BRK */
    dp = dm_buf;
    if (err || dp == NULL || dp != read_buf) {
      call Panic.panic(PANIC_DM, 6, err, (parg_t) dp, (parg_t) read_buf, 0);
      return;
    }

    switch(dm_state) {
      default:
        dm_panic(7, dm_state, 0);
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
          dm_panic(8, err, 0);
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
          dm_panic(9, (parg_t) cur_blk, 0);
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

    /* end of dblk has been determined, now need to find last valid record to
     * calculate the record number and datetime to start with.
     *
     * we start by first finding the last valid sync record. this is accomplished
     * by calling Resync.start() with the terminal address set to  sixteen sectors
     * before the end of dblk. This indicates we want to search backwards which
     * should bring us to the last sync record.
     *
     * if we find the sync record immediately, then we can start the search for
     * for the last record. otherwise we need to wait for the search to complete
     * when Resync.done() event is called.
     */
    dm_state = DMS_SYNC;
    call SDResource.release();
    dmc.cur_offset = call DblkManager.dblk_nxt_offset();
    err = call Resync.start(&dmc.cur_offset, dmc.cur_offset - (16 * SD_BLOCKSIZE));
    switch (err) {
      case SUCCESS:
        dm_state = DMS_LAST_REC;
        post dblk_last_task();
        break;
      case EBUSY:
        break;
      default:
        dm_panic(22, err, 0);
    }
  }


  event void Resync.done(error_t err, uint32_t offset) {
    // make sure we are expecting this
    if (dm_state != DMS_SYNC) dm_panic(33, err, offset);
    if (err == SUCCESS) {
        dmc.cur_offset = offset;
        dm_state = DMS_LAST_REC;
        post dblk_last_task();
    } else
      dm_panic(55, err, dmc.cur_offset);
  }


  event void DMF.data_avail(error_t err) {
    // make sure we are expecting this
    if (dm_state != DMS_LAST_REC) dm_panic(44, err, 0);
    post dblk_last_task();
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


  /*
   * Validate a header by verifing its CRC.
   *
   * header pointed to by header is assumed to be sizeof(dt_header_t)
   * The hdr_crc8 does NOT include the recsum.  This is corrected for
   * via HDR_CRC_LEN and recsum is last in the hdr block.
   */
  async command bool DblkManager.hdrValid(dt_header_t *header) {
    uint8_t crc0, crc1;

    crc0 = header->hdr_crc8;
    header->hdr_crc8 = 0;
    crc1 = call Crc8.crc((void *) header, sizeof(dt_header_t));
    header->hdr_crc8 = crc0;
    if (crc0 == crc1)
      return TRUE;
    return FALSE;
  }


  event void FileSystem.eraseDone(uint8_t which) { }

  async event void Panic.hook() { }
}
