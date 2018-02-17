/*
 * Copyright (c) 2017 Daniel J. Maltbie
 * Copyright (c) 2018 Daniel J. Maltbie, Eric B. Decker
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
 * Contact: Daniel J. Maltbie <dmaltbie@daloma.org>
 *          Eric B. Decker <cire831@gmail.com>
 */

/**
 * This module handles Byte access to Dblk Stream storage using
 * the ByteMapFile interface.
 */

#include <TinyError.h>
#include <panic.h>
#include <platform_panic.h>
#include <sd.h>

/*
 * dblk_map_cache_t   defines the information context representing
 *                    the dblk file cache.
 *
 * A cache blk is identified its sector block id, the file offset
 * of the start of the block and the file offset of the end of block.
 * This maps the logical file space to the cache buffer as well as
 * ensures that the cache buffer is updated as necessary.
 *
 * Three flags are maintained to track the progress of block reads
 * and the last err is remembered.
 *
 * When a block read is pending, then mapping cannot be performed
 * and the EBUSY error is returned.
 *
 * The end of data is also detected and returned as the EODATA error.
 */
typedef struct {
  struct {
    uint32_t             id;         // storage block id
    uint32_t             offset;     // file offset of start of block
    uint32_t             end;        // file offset of end of block
  }   blk;
  error_t              err;          // last error encountered
  bool                 sbuf_ready;   // true if sbuf has valid data
  bool                 sbuf_requesting; // true if sd.request in progress
  bool                 sbuf_reading; // true if sd.read in progress
} dblk_map_cache_t;

module DblkMapFileP {
  provides  interface ByteMapFileNew as DMF;
  uses {
    interface StreamStorage as SS;
    interface SDread        as SDread;
    interface Resource      as SDResource;
    interface Boot;
    interface Panic;
  }
}
implementation {
  dblk_map_cache_t dmf_cb;
  uint8_t          dmf_sbuf[SD_BLOCKSIZE] __attribute__ ((aligned (4)));

  void dmap_panic(uint8_t where, parg_t p0, parg_t p1) {
    call Panic.panic(PANIC_TAGNET, where, p0, p1, dmf_cb.sector.base,
                     dmf_cb.sector.eof);
  }


  event void SDResource.granted() {
    dmf_cb.sbuf_requesting = FALSE;
    if ((!dmf_cb.sbuf_ready) && (dmf_cb.sector.cur)) {
      if (!call SDread.read(dmf_cb.sector.cur, dmf_sbuf)) {
        dmf_cb.sbuf_reading = TRUE;
        return;
      }
    }
    call SDResource.release();
  }


  event void SDread.readDone(uint32_t blk_id, uint8_t *read_buf, error_t err) {
    call SDResource.release();
    dmf_cb.sbuf_ready      = TRUE;
    dmf_cb.sbuf_requesting = FALSE;
    dmf_cb.sbuf_reading    = FALSE;

    /* return original call's data so we can match if we want. */
    signal DMF.data_avail(0, 0, 0);
  }


  command error_t DMF.map(uint32_t context, uint8_t **bufp,
                          uint32_t offset, uint32_t *lenp) {
    uint32_t    count  = 0;
    uint8_t   **blk_bufp;
    uint32_t   *blk_lenp;

    if ((offset + len) >= dmf_cb.blk.end) {
      return EODATA;  // offset beyond end of file
    }
    // try to fill request from the cache buffer
    if ((dmf_cb.blk.id) && \ // skip if id is zero (eg. startup)
        (dmf_cb.sbuf_ready)) { // and not ready
      if ((offset >= dmf_cb.blk.offset) &&
          ((offset + *lenp) < dmf_cb.blk.end)) {
        *bufp = &dmf_sbuf[offset%SD_BLOCKSIZE]; // fill request
        if (dmf_cb.blk.end < (offset + *lenp))
          *lenp = dmf_cb.blk.end - offset;
        return SUCCESS;
      }
    }
    // get info on where data for request can be found
    dmf_cb.blk.id = call SS.where(context, offset,
                                  &blk_bufp, &blk_lenp);
    if (*blk_bufp) {    // data is in StreamWriter memory
      for (x = 0; x < *blk_lenp; x++) {  // copy into cache
        dmf_sbuf[x] = blk_bufp[x];
      }
      dmf_cb.blk.offset = (offset/SD_BLOCKSIZE) * SD_BLOCKSIZE;
      dmf_cb.blk.end = dmf_cb.blk.offset + *blk_lenp;
      *bufp = &dmf_sbuf[offset%SD_BLOCKSIZE]; // fill request
      if (dmf_cb.blk.end < (offset + *lenp))
        *lenp = dmf_cb.blk.end - offset;
      return SUCCESS;
    }
    if (dmf_cb.blk.id) { // data is on SD card
      dmf_cb.sbuf_ready      = FALSE;
      dmf_cb.sbuf_requesting = TRUE;
      dmf_cb.sbuf_reading    = FALSE;
      dmf_cb.blk.offset = (offset/SD_BLOCKSIZE) * SD_BLOCKSIZE;
      dmf_cb.blk.end    = dmf_cb.blk.offset + SD_BLOCKSIZE;
      dmf_cb.err = call SDResource.request();
      if (dmf_cb.err != SUCCESS)
        return FAIL;
    }
    return EBUSY;
  }


  command uint32_t DMF.filesize(uint32_t context) {
    return call SS.eof_offset();
  }


  command uint32_t DMF.commitsize(uint32_t context) {
    return 0;
  }


  event void Boot.booted() {
    dmf_cb.blk.id           = 0;
    dmf_cb.blk.offset       = 0;
    dmf_cb.blk.start        = 0;
    dmf_cb.sector.cur       = 0;
    dmf_cb.sbuf_ready       = FALSE;
    dmf_cb.sbuf_requesting  = FALSE;
    dmf_cb.sbuf_reading     = FALSE;
  }


          event void SS.dblk_stream_full() { }
  async   event void Panic.hook()          { }
  default event void DMF.data_avail(uint32_t context, uint32_t offset,
                                    uint32_t len) { }
}
