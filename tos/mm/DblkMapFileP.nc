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
 * the dblk cache always stores sectors or partial sectors (if the
 * last sector being written by the data stream).  The cache contents
 * is identified by the starting offset of the block and its length.
 * In addition we also store the absolute blk_id of the sector but
 * this can also be derived from the block offset (but would be needed
 * to be added to dblk_low to get the absolute block).
 *
 * Three flags are maintained to track the progress of block reads
 * and the last err is remembered.  These datums are for informational
 * purposes only and do not effect the algorithm.
 *
 * Only one map() call can be pending at a time.  Either the map call
 * can be satisfied immediately (cache hit) or the underlying data store
 * will be accessed using split phase.  While this underlying read
 * is pending any other map() calls will be aborted with EBUSY.
 */

typedef struct {
  struct {
    uint32_t             id;         // storage block id - 0 if cache invalid
    uint32_t             offset;     // file offset of cached block
    uint32_t             len;        // how much is in the cache.
  } cache;

  uint32_t             fill_blk_id;  // blk_id being brought into the cache
  error_t              err;          // last error encountered
  bool                 ready;        // true if cache has valid data
  bool                 requested;    // true if sd.request in progress
  bool                 reading;      // true if sd.read in progress
} dblk_map_cache_t;

#ifndef PANIC_DM
enum {
  __pcode_dm = unique(UQ_PANIC_SUBSYS)
};

#define PANIC_DM __pcode_dm
#endif


module DblkMapFileP {
  provides  interface ByteMapFile as DMF;
  uses {
    interface StreamStorage as SS;
    interface SDread        as SDread;
    interface Resource      as SDResource;
    interface Panic;
  }
}
implementation {
  dblk_map_cache_t dmf_cb;
  uint8_t          dmf_cache[SD_BLOCKSIZE] __attribute__ ((aligned (4)));

  void dmap_panic(uint8_t where, parg_t p0, parg_t p1) {
    call Panic.panic(PANIC_DM, where, p0, p1, dmf_cb.cache.id,
                     dmf_cb.cache.len);
  }


  command error_t DMF.map(uint32_t context, uint8_t **bufp,
                          uint32_t offset, uint32_t *lenp) {
    uint32_t    blk_id;
    uint32_t    len;
    uint32_t    blk_offset;
    uint8_t    *blk_buf;
    uint32_t    len_avail;
    uint32_t   *src, *dst, count;

    /* if we are in the middle of bringing a new block in, no new requests */
    if (dmf_cb.fill_blk_id)
      return EBUSY;

    if (!lenp || !bufp)                 /* nulls are very bad */
      dmap_panic(32, 0, 0);

    if (*lenp == 0) {                   /* asking for nothing? */
      *bufp = NULL;                     /* no buffer */
      return EINVAL;                    /* should we return SUCCESS? */
    }

    /*
     * see if we have a cache hit.
     * we will have a cache hit iff:
     *
     *    cache.offset <= offset < cache.offset + cache.len
     *
     * minimum one byte, or *lenp, or len_avail in cache.
     */

    if (dmf_cb.cache.id &&              /* cache valid? */
        (dmf_cb.cache.offset <= offset) &&
        (offset < (dmf_cb.cache.offset + dmf_cb.cache.len))) {
      *bufp = &dmf_cache[(offset - dmf_cb.cache.offset)];

      /* check and possibly modify how much data we can make available */
      len_avail = dmf_cb.cache.offset + dmf_cb.cache.len - offset;
      if (len_avail < *lenp)
        *lenp = len_avail;
      return SUCCESS;
    }

    /* cache miss, ask the low level where things live */
    blk_id = call SS.where(context, offset, &len, &blk_offset, &blk_buf);
    if (!blk_id) {                      /* past eof   */
      *bufp = NULL;                     /* no result  */
      *lenp = 0;                        /* no result  */
      return EODATA;
    }

    /* invalidate current cache */
    dmf_cb.cache.id = 0;

    /*
     * we got something...
     *
     * blk_id     tells where this sector has been or will be written, abs blk_id
     * len        tells how much data is available.
     * blk_offset tells the offset of the start of the block.
     * blk_buf    will have a pointer to a buffer if the data is in memory
     *
     * if we have to go get the data from disk, buf will be NULL.
     */

    if (blk_buf) {
      /*
       * data is in SSW (low level) memory waiting to go out.
       * we need to copy it into the cache and update our control cells.
       */
      src   = (uint32_t *) blk_buf;
      dst   = (uint32_t *) dmf_cache;
      count = len;
      while (count > 3) {
        *dst++ = *src++;
        count -= 4;                     /* quads */
      }
      if (count)
        *dst++ = *src++;

      /* update control datums */
      dmf_cb.cache.id     = blk_id;
      dmf_cb.cache.offset = blk_offset;
      dmf_cb.cache.len    = len;

      *bufp = &dmf_cache[(offset - dmf_cb.cache.offset)];

      /* check and possibly modify how much data we can make available */
      len_avail = dmf_cb.cache.offset + dmf_cb.cache.len - offset;
      if (len_avail < *lenp)
        *lenp = len_avail;
      return SUCCESS;
    }

    /*
     * data is out on disk.  we need to read it into the cache.
     */
    dmf_cb.fill_blk_id  = blk_id;
    dmf_cb.ready        = FALSE;
    dmf_cb.requested    = FALSE;
    dmf_cb.reading      = FALSE;
    dmf_cb.cache.offset = blk_offset;
    dmf_cb.cache.len    = len;
    dmf_cb.err = call SDResource.request();
    if (dmf_cb.err != SUCCESS) {
      dmap_panic(33, dmf_cb.err, 0);
      dmf_cb.fill_blk_id  = 0;
      return FAIL;
    }
    dmf_cb.requested   = TRUE;
    return EBUSY;
  }


  event void SDResource.granted() {
    dmf_cb.requested = FALSE;
    dmf_cb.err = call SDread.read(dmf_cb.fill_blk_id, dmf_cache);
    if (dmf_cb.err) {
      dmap_panic(34, dmf_cb.err, 0);
      dmf_cb.fill_blk_id = 0;
      call SDResource.release();
      signal DMF.data_avail(dmf_cb.err);
      return;
    }
    dmf_cb.reading = TRUE;
    return;
  }


  event void SDread.readDone(uint32_t blk_id, uint8_t *read_buf, error_t err) {
    if (blk_id != dmf_cb.fill_blk_id ||
        read_buf != dmf_cache || err)
      dmap_panic(35, err, blk_id);
    dmf_cb.fill_blk_id = 0;             /* err or success, open lock */
    call SDResource.release();
    if (err) {
      dmf_cb.err         = err;
      signal DMF.data_avail(err);
      return;
    }
    dmf_cb.ready      = TRUE;
    dmf_cb.requested  = FALSE;
    dmf_cb.reading    = FALSE;
    dmf_cb.cache.id = blk_id;           /* validate */
    signal DMF.data_avail(SUCCESS);
  }


  command uint32_t DMF.filesize(uint32_t context) {
    return call SS.eof_offset();
  }


  command uint32_t DMF.commitsize(uint32_t context) {
    return call SS.committed_offset();
  }


          event void SS.dblk_stream_full() { }
          event void SS.dblk_advanced(uint32_t last) { }
  async   event void Panic.hook()          { }
  default event void DMF.data_avail(error_t err)  { }
}
