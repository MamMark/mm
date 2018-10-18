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
#include <typed_data.h>

/*
 * DblkMapFile provides a virtualization of dblk stream storage
 * by providing a mapping of the logical file offset to underlying
 * stream and sector storage. The caller provides an offset into
 * the dblk file and a length. DblkMapFile returns a physical
 * memory address where dblk data has been copied from from disk
 * and the amount of data available in memory of the requested
 * offset and length.
 *
 * DblkMapFile provides two modes of operation, MAP_ANY and
 * MAP_ALL.  MAP_ANY will respond with any bytes in the cache up
 * to the requested number of bytes.  That is if any bytes are
 * cached those bytes will be retured with no further disk activity.
 *
 * In MAP_ALL mode, all bytes requested must be in the cache
 * to satisfy the request.  If a partial number of bytes are
 * currently in the cache, these will be saved and the remainder
 * of the bytes brought in from the appropriate sector.
 *
 * MAP_ALL works both in a forward as well as a reverse direction.
 * Forward occurs when the partial is at the end of a sector and
 * new bytes are brought in from the following (forward) sector.
 * If the partial bytes requested occur at the start of the
 * cache, then we will fetch the previous sector (backward).
 *
 * If no portion of the requested data is in the cache, a full miss
 * occurs resulting in bringing in the sector that contains the
 * first part of any requested data.
 *
 * If the requested data can't be resolved without going past the
 * current EOF, an error return of EODATA (end of data) will
 * be returned.
 *
 * The size of the cache needs to be at least the size of one
 * disk sector in both modes.  When using MAP_ALL, we want to
 * end with all requested bytes in the cahce.  The maximum
 * size that can be requested will be a sector size + the size
 * any additional data that can be handled.  For our typical case,
 * of a sync header, this will be 24 bytes + 512 bytes.
 *
 * The steps below illustrate the MAP_ALL mode of operation
 * in the case where the requested data spans the disk sector
 * boundary. The DMF.mapAll() call must satisfy access to all
 * bytes requested or return busy while it assembles the right
 * data into the cache.  Assembling the data requires saving
 * some of the current sector to be prepended/appended to the
 * next sector of dblk file data retrieved. Once all data is in
 * the cache, the DMF.mapAll() call will succeed with
 * the cache address where offset of data starts and at
 * least length amount of data available.
 *
 * (1)  Cache state has one sector worth of data with last
 *      four bytes having the value '1234'
 *       {offset=0, blk_id=1, len=512, data=[...1234]}
 * (2)  User call DMF.mapAll requesting offset=508 and len=8
 * (2a) Call copy_block(src=508, dst=0, len=4) to copy the
 *      portion of data in the cache that partially satisfies
 *      the mapAll request from the end of the cache to the
 *      beginning, since it will be prepended to any additional
 *      data retrieved
 * (2b) Call SS.where(offset,...) to find out where more data
 *      can be found (in stream buffers or on disk). In this
 *      example, the call returns a new blk_id=2 specifying the
 *      next sector of data to retrieve from disk
 * (2c) Cache state after prepended data copy
 *       {offset=508,blk_id=2,len=4,data=[1234]}
 * (2d) Initiate SD read using (blk_id, &cache[cache.len], 512)
 *      to retrieve the next 512 bytes of data. It will be stored
 *      immediately after prepend data in cache (partial data
 *      from previous sector)
 * (2e) DMF.mapAll call returns <= (EBUSY) to indiate that it
 *      is busy handling the callers request
 * (3)  Time passes as disk read is performed
 * (4)  Signal of sd.readDone(sector=blk_id, buf=&cache[cache.len],
 *      len=512) verifies and updates state information based
 *      on success of the sector read.
 * (4a) Cache state after SD.readDone() success shows that the
 *      cache offset has been advanced to where the prepended
 *      data starts and the length includes both the prepend
 *      as well as the sector of data just read from disk.
 *       {offset=508,blk_id=2,len=516,data=[1234abcd...]}
 * (4b) DMF.data_avail() is called to signal that new data is
 *      available for user
 * (5)  Time passes as user task is scheduled
 * (6)  User calls DMF.mapAll(offset=508, len=8) again to
 *      see if data is now available.
 * (6a) Returns <= (SUCCESS, data=[1234abcd], len=8) succcess
 *      with pointer to cache where data is found and length
 *      that is equal to amount requested
 *
 * The control structure includes various data cells that indicate
 * the current state of the DblkMap system.
 *
 * Only one map() call can be pending at a time.  Either the map call
 * can be satisfied immediately (cache hit) or the underlying data store
 * will be accessed using split phase.  While this underlying read
 * is pending any other map() calls will be aborted with EBUSY.
 *
 * The cache is quad (4-byte) aligned and quad granular therefore
 * copies to the cache are quad aligned. Note that the Map interface
 * provides a byte granular access.
 */

/*
 * CACHE_SIZE    amount of memory allocated for holding dblk data
 *               including space for one disk sector and largest
 *               amount of prepended data required by MapAll. This
 *               is currently defined as enough space to hold the
 *               sync record in support of sync search. This also
 *               covers the case of space for generic record
 *               header, which is part of the sync record. The
 *               maximum prepend length is one word less than the
 *               entire structure, since this is the worst case
 *               (otherwise the map would have succeeded)
 * CACHE_PREPEND_SIZE
 *               maximum amount of data that can be prepended
 *               when handling MAP_ALL mode.
 * CACHE_WORD    granular size of cache is one 32-bit word
 */
#define CACHE_PREPEND_SIZE (DT_HDR_SIZE_SYNC - sizeof(uint32_t))
#define CACHE_SIZE (SD_BLOCKSIZE + CACHE_PREPEND_SIZE)
#define CACHE_WORD (sizeof(uint32_t))

/*
 * Modes of operation provided by mapit.
 *
 * MAP_ANY       successful when at least one byte requested
 *               by user is in cache
 * MAP_ALL       successful when all bytes requested in cache
 */
typedef enum {
  MAP_ANY  = 0,
  MAP_ALL  = 1,
} dblk_map_mode_t;


typedef enum {
  DMF_IO_IDLE = 0,
  DMF_IO_REQUESTED,
  DMF_IO_READING,
  DMF_IO_READY,
  DMF_IO_ERROR,
} dmf_io_state_t;

/*
 * dblk_map_cache_t   defines the information context representing
 *                    the dblk file cache.
 */
typedef struct {
  struct {
    uint32_t             offset;     // logical file offset of cached data
    uint32_t             len;        // how much is in the cache, 0 = empty
    uint32_t             id;         // physical blk number, info only
    uint32_t      target_offset;     // fill target offset.
    uint32_t             extra;      // extra data length
  } cache;

  uint32_t             fill_blk_id;  // absolute SD blk_id in the cache
  error_t              err;          // last error encountered
  uint8_t              cid;          // client ID.
  dmf_io_state_t       io_state;
} dblk_map_control_t;


#ifndef PANIC_DM
enum {
  __pcode_dm = unique(UQ_PANIC_SUBSYS)
};

#define PANIC_DM __pcode_dm
#endif

#define RNDWORDUP(n)  (((n) + 3) & ~3UL)
#define RNDWORDDN(n)  ((n) & ~3UL)
#define RNDBLKUP(n)   (((n) + (SD_BLOCKSIZE-1)) & ~(SD_BLOCKSIZE-1))
#define RNDBLKDN(n)   ((n) & ~(SD_BLOCKSIZE-1))

module DblkMapFileP {
  provides  interface ByteMapFile as DMF[uint8_t cid];
  uses {
    interface StreamStorage as SS;
    interface SDread        as SDread;
    interface Resource      as SDResource;
    interface Panic;
  }
}
implementation {
  // dlbk control block
  dblk_map_control_t dmf_cb;

  // dblk cache space
  uint8_t  dmf_cache[CACHE_SIZE] __attribute__ ((aligned (4)));


  void dmap_panic(uint8_t where, parg_t p0, parg_t p1) {
    call Panic.panic(PANIC_DM, where, p0, p1, dmf_cb.cache.id,
                     dmf_cb.cache.len);
  }

  uint32_t copy_block(uint32_t *src, uint32_t *dst, uint32_t count) {
    uint32_t  rc = count;

    if (((uint32_t) src % CACHE_WORD) ||
        ((uint32_t) dst % CACHE_WORD) ||
        (count % CACHE_WORD))
      call Panic.panic(PANIC_DM, 10, (parg_t) src, (parg_t) dst, count, 0);
    if ((count > (CACHE_SIZE - dmf_cb.cache.len)) ||
        (dmf_cb.cache.len > CACHE_SIZE))
      dmap_panic(11, count, dmf_cb.cache.len);
    while (count > 3) {
      *dst++ = *src++;
      count -= CACHE_WORD;        /* quads */
    }
    if (count)                    /* round up */
      *dst++ = *src++;
    return RNDWORDUP(rc);
  }


  /* return TRUE if offset is inside the current cache */
  bool in_cache(uint32_t offset) {
    if (dmf_cb.cache.len == 0)
      return FALSE;
    if (dmf_cb.cache.offset <= offset &&
        offset < dmf_cb.cache.offset + dmf_cb.cache.len)
      return TRUE;
    return FALSE;
  }


  error_t mapit(uint8_t cid, uint32_t context, uint8_t **bufp,
                uint32_t offset, uint32_t *lenp, dblk_map_mode_t map_mode) {
    uint32_t    blk_id;
    uint32_t    len;
    uint32_t    blk_offset;
    uint8_t    *blk_buf;
    uint32_t    len_avail;
    bool        hit;
    uint32_t    lower, upper;

    /* if we are in the middle of reading SD data, no new requests */
    if (dmf_cb.fill_blk_id)
      return EBUSY;

    dmf_cb.cid = cid;

    if (!lenp || !bufp)                 /* nulls are very bad */
      dmap_panic(0, 0, 0);

    /* asking for nothing or more than fits in the cache for mapAll */
    if ((*lenp == 0) || ((map_mode == MAP_ALL) && (*lenp > CACHE_SIZE))) {
      dmap_panic(3, 0, 0);
    }

    /*
     * sanity check the cache.  The cache should be both quad aligned
     * as well as quad granular.
     */
    if ((dmf_cb.cache.offset & 3) || (dmf_cb.cache.len & 3))
      dmap_panic(4, dmf_cb.cache.offset, dmf_cb.cache.len);

    /*
     * see if we have a cache hit. we will have a cache hit iff:
     *
     * MAP_ANY: 1 or more of the requested bytes (starting at offset)
     * are in the cache.
     *
     * MAP_ALL: all requested bytes must be in the cache for a hit.
     */
    hit = FALSE;
    if (dmf_cb.cache.len) {             /* cache valid? */
      switch (map_mode) {
        case MAP_ANY:
          if (in_cache(offset))
            hit = TRUE;
          break;
        case MAP_ALL:
          if (in_cache(offset) && in_cache(offset + *lenp - 1))
            hit = TRUE;
          break;
        default:
          break;
      }
    }
    if (hit) {
      *bufp = &dmf_cache[(offset - dmf_cb.cache.offset)];

      /* check and possibly modify how much data we can make available */
      len_avail = dmf_cb.cache.offset + dmf_cb.cache.len - offset;
      if (len_avail < *lenp) {
        if (map_mode == MAP_ALL)
          // shouldn't get here because of conditional tests above
          dmap_panic(5, len_avail, *lenp);
        *lenp = len_avail;
      }
      return SUCCESS;
    }

    /*
     * Cache Miss.
     *
     * If MAP_ALL, check for partial miss.
     * If partial hit, copy any partial data to where it belongs.
     * Afterwards, we will lay down a new sector to fill in the
     * missing data.
     *
     * For MAP_ALL, look for any overlap that exists in the cache.
     * If the overlap is at the end of the cache (forward), copy
     * the end to the beginning of the cache and fill in behind
     * the copied data.
     *
     * If the overlap is at the beginning (backward), copy the data
     * to the end of the cache such that it will line up with the
     * incoming sector data landing in the front of the cache.
     */
    hit = FALSE;
    if (dmf_cb.cache.len) {             /* cache valid? */
      if (map_mode == MAP_ALL) {
        /* first check for forward straddle */
        if (in_cache(offset) && !in_cache(offset + *lenp - 1)) {
          /* cache only the bit between offset (lower) and end of cache */
          lower = RNDWORDDN(offset);
          dmf_cb.cache.len = dmf_cb.cache.offset + dmf_cb.cache.len - lower;
          if (dmf_cb.cache.len + SD_BLOCKSIZE > CACHE_SIZE)
            dmap_panic(5, dmf_cb.cache.extra, 0);
          copy_block(
            (uint32_t *) &dmf_cache[lower - dmf_cb.cache.offset],
            (uint32_t *) &dmf_cache[0],
            dmf_cb.cache.len);
          dmf_cb.cache.offset = lower;
          dmf_cb.cache.target_offset = dmf_cb.cache.offset + dmf_cb.cache.len;
          dmf_cb.cache.extra = 0;       /* nothing extra */
          hit = TRUE;
        } else
          if (!in_cache(offset) && in_cache(offset + *lenp - 1)) {
            /* backward straddle */
            upper = RNDWORDUP(offset + *lenp);
            dmf_cb.cache.extra = upper - dmf_cb.cache.offset;
            if (dmf_cb.cache.extra + SD_BLOCKSIZE > CACHE_SIZE)
              dmap_panic(6, dmf_cb.cache.extra, 0);
            copy_block(
              (uint32_t *) &dmf_cache[0],
              (uint32_t *) &dmf_cache[SD_BLOCKSIZE],
              dmf_cb.cache.extra);
            dmf_cb.cache.target_offset = dmf_cb.cache.offset =
              RNDBLKDN(offset);
            dmf_cb.cache.len = 0;       /* for now empty, til we fill */
            hit = TRUE;
          }
      }
    }
    if (!hit) {                         /* no partial */
      dmf_cb.cache.len    = 0;          /* nothing in cache */
      dmf_cb.cache.target_offset = dmf_cb.cache.offset = RNDBLKDN(offset);
      dmf_cb.cache.extra  = 0;
    }
    dmf_cb.cache.id = 0;          /* invalidate blk_id currently in cache*/

    /*
     * Check Stream Storage where more data is located, stream
     * buffer or disk, or end of file.
     *
     * Collect has the last buffer (eof buffer).  Collect only copies
     * out records that are quad aligned (all header start on quad alignment)
     * and quad granular (see header alignment).
     *
     * That means if we have a partial buffer that we copy into the cache
     * it will be quad granular and the cache is always an aligned number of
     * quad bytes.
     */
    blk_id = call SS.where(context,
                           dmf_cb.cache.target_offset,
                           &len,
                           &blk_offset,
                           &blk_buf);
    if (!blk_id) {                      /* past eof   */
      *bufp = NULL;                     /* no result  */
      *lenp = 0;                        /* no result  */
      return EODATA;
    }

    /* make sure new data is what we expected in cache alignment */
    if (blk_offset != dmf_cb.cache.target_offset)
      dmap_panic(6, blk_offset, dmf_cb.cache.target_offset);

    /*
     * we got something...
     *
     * blk_id     tells where this sector has been or will be written, abs blk_id
     * len        tells how much data is available.
     * blk_offset tells the offset of the start of the block.
     * blk_buf    will have a pointer to a buffer if the data is in memory
     *
     * if we have to go get the data from disk, blk_buf will be NULL.
     */

    /*
     * data is in Stream Storage memory waiting to go out to SD.
     * copy it into the cache and update our control cells.
     *
     * Also need to account for any data preserved in cache from before.
     * len coming back from SS.where should be quad granular.
     */
    if (blk_buf) {
      if (((dmf_cb.cache.len + len) > CACHE_SIZE) || (len & 3))
        dmap_panic(7, dmf_cb.cache.len, len);
      dmf_cb.cache.len += copy_block(
        (uint32_t *) blk_buf,
        (uint32_t *) &dmf_cache[dmf_cb.cache.target_offset
                                - dmf_cb.cache.offset],
        len);
      dmf_cb.cache.id     = blk_id;
      /* set bufp return value to address in cache for requested byte offset */
      *bufp = &dmf_cache[(offset - dmf_cb.cache.offset)];

      /* check and possibly modify how much data we can make available */
      len_avail = dmf_cb.cache.offset + dmf_cb.cache.len - offset;
      if (len_avail < *lenp){
        if (map_mode == MAP_ALL) {
          /*
           * the only way for length to be less than 512 is the last
           * valid block in Stream buffers and is partial.  ie. being actively
           * worked on by Collect.
           *
           * This is a nasty corner case.  The last buffer is a partial (len < 512)
           * The cache contains partial data copied from a partial write cache buffer.
           * And we ran off the end of it.  To avoid cache coherency problems, we
           * need to invalidate the read cache (dmf_cache) to force an update from
           * the write cache (stream writer) if a later request comes in for the same
           * data.
           */
          if (len < SD_BLOCKSIZE) {
            *bufp = NULL;
            *lenp = 0;
            dmf_cb.cache.len = 0;
            dmf_cb.cache.id  = 0;
            return EODATA;
          }
          dmap_panic(8, len_avail, *lenp);
        }
        *lenp = len_avail;
      }
      return SUCCESS;
    }

    /*
     * Read next block of data from SD into the cache.
     */
    if (dmf_cb.cache.len % CACHE_WORD)          // panic if not word aligned
      dmap_panic(5, dmf_cb.cache.len, blk_id);
    if ((sizeof(dmf_cache) - dmf_cb.cache.len) < SD_BLOCKSIZE)
      dmap_panic(7, dmf_cb.cache.len, sizeof(dmf_cache));
    dmf_cb.fill_blk_id  = blk_id;
    dmf_cb.io_state     = DMF_IO_IDLE;
    dmf_cb.err = call SDResource.request();
    if (dmf_cb.err != SUCCESS) {
      dmf_cb.io_state = DMF_IO_ERROR;
      dmap_panic(6, dmf_cb.err, 0);
      dmf_cb.fill_blk_id  = 0;
      return FAIL;
    }
    dmf_cb.io_state = DMF_IO_REQUESTED;
    return EBUSY;
  }


  command error_t DMF.map[uint8_t cid](uint32_t context, uint8_t **bufp,
                                       uint32_t offset, uint32_t *lenp) {
    return mapit(cid, context, bufp, offset, lenp, MAP_ANY);
  }


  command error_t DMF.mapAll[uint8_t cid](uint32_t context, uint8_t **bufp,
                                          uint32_t offset, uint32_t *lenp) {
    return mapit(cid, context, bufp, offset, lenp, MAP_ALL);
  }


  event void SDResource.granted() {
    dmf_cb.err = call SDread.read(dmf_cb.fill_blk_id,
        &dmf_cache[dmf_cb.cache.target_offset - dmf_cb.cache.offset]);
    if (dmf_cb.err) {
      dmf_cb.io_state = DMF_IO_ERROR;
      dmap_panic(8, dmf_cb.err, 0);
      dmf_cb.fill_blk_id = 0;
      call SDResource.release();
      dmf_cb.io_state = DMF_IO_IDLE;
      signal DMF.data_avail[dmf_cb.cid](dmf_cb.err);
      return;
    }
    dmf_cb.io_state = DMF_IO_READING;
    return;
  }


  event void SDread.readDone(uint32_t blk_id, uint8_t *read_buf, error_t err) {
    if (blk_id != dmf_cb.fill_blk_id ||         // panic if wrong read completed
        read_buf != &dmf_cache[dmf_cb.cache.target_offset - dmf_cb.cache.offset]
        || err)
      dmap_panic(9, err, blk_id);
    dmf_cb.fill_blk_id = 0;             /* err or success, open lock */
    call SDResource.release();
    if (err) {
      dmf_cb.io_state = DMF_IO_ERROR;
      dmf_cb.err = err;
      signal DMF.data_avail[dmf_cb.cid](err);
      return;
    }
    dmf_cb.io_state = DMF_IO_READY;
    dmf_cb.cache.id   = blk_id;
    dmf_cb.cache.len += SD_BLOCKSIZE;  /* and add sector to cache size */
    signal DMF.data_avail[dmf_cb.cid](SUCCESS);
  }


  command uint32_t DMF.filesize[uint8_t cid](uint32_t context) {
    return call SS.eof_offset();
  }


  command uint32_t DMF.commitsize[uint8_t cid](uint32_t context) {
    return call SS.committed_offset();
  }


          event void SS.dblk_stream_full() { }
          event void SS.dblk_advanced(uint32_t last) { }
  async   event void Panic.hook()          { }
  default event void DMF.data_avail[uint8_t cid](error_t err) {
    dmap_panic(10, cid, 0);
  }
}
