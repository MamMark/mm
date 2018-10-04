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
 * DblkMapFile provides two modes of operation. The first mode
 * MAP_ANY returns at least one byte of valid cache address
 * space (cache hit of one or more bytes). The second mode
 * MAP_ALL requires all bytes requested be in valid cache space
 * (that is, a cache hit for all bytes specified by offset
 * and length). In both cases, a cache miss returns an EBUSY
 * error to indicate when the cache needs to be refilled oe
 * an EODATA when end of file condition is detected.
 *
 * The size of the cache needs to be at least the size of one
 * disk sector in both modes. For MAP_ALL mode, the cache needs
 * additional space to hold partial data from the previous
 * sector is prepended to the data retrieved from Stream
 * Storage (up to one sector) or disk (always one sector).
 *
 * The steps below illustrate the MAP_ALL mode of operation
 * in the case where the requested data spans the disk sector
 * boundary. The DMF.mapAll() call must satisfy access to all
 * bytes requested or return busy while it assembles the right
 * data into the cache. Assembling the data requires saving
 * some of the current sector to be prepended to the next
 * sector of dblk file data retrieved. Once all data is in
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
 * Three flags are maintained to track the progress of block reads
 * and the last err is remembered.  These datums are for informational
 * purposes only and do not effect the algorithm.
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

/*
 * dblk_map_cache_t   defines the information context representing
 *                    the dblk file cache.
 */
typedef struct {
  struct {
    uint32_t             offset;     // logical file offset of cached data
    uint32_t             len;        // how much is in the cache, 0 = empty
    uint32_t             id;         // physical blk number, info only
  } cache;

  uint32_t             fill_blk_id;  // absolute SD blk_id in the cache
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

#define RNDWORDUP(n)  (((n/CACHE_WORD)+1)*CACHE_WORD)
#define RNDWORDDN(n)  ((n/CACHE_WORD)*CACHE_WORD)
#define RNDBLKUP(n)   (((n/SD_BLOCKSIZE)+1)*SD_BLOCKSIZE)
#define RNDBLKDN(n)   ((n/SD_BLOCKSIZE)*SD_BLOCKSIZE)


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
  // dlbk control block
  dblk_map_cache_t dmf_cb;
  // dblk cache space
  uint8_t  dmf_cache[CACHE_SIZE] __attribute__ ((aligned (4)));


  void dmap_panic(uint8_t where, parg_t p0, parg_t p1) {
    call Panic.panic(PANIC_DM, where, p0, p1, dmf_cb.cache.id,
                     dmf_cb.cache.len);
  }

  uint32_t copy_block(uint32_t *src, uint32_t *dst, uint32_t count) {
    uint32_t  rc = count;

    if ((uint32_t) src % CACHE_WORD)
      dmap_panic(10, (uint32_t) src, count);
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

  error_t mapit(uint32_t context, uint8_t **bufp,
                uint32_t offset, uint32_t *lenp, dblk_map_mode_t map_mode) {
    uint32_t    blk_id;
    uint32_t    len;
    uint32_t    blk_offset;
    uint8_t    *blk_buf;
    uint32_t    len_avail;

    /* if we are in the middle of reading SD data, no new requests */
    if (dmf_cb.fill_blk_id)
      return EBUSY;

    if (!lenp || !bufp)                 /* nulls are very bad */
      dmap_panic(0, 0, 0);

    /* asking for nothing or more than fits in the cache for mapAll */
    if ((*lenp == 0) || ((map_mode == MAP_ALL) && (*lenp > CACHE_SIZE))) {
      dmap_panic(3, 0, 0);
    }

    /* sanity check cache offset for quad word alignment */
    if (dmf_cb.cache.offset % CACHE_WORD)
      dmap_panic(4, dmf_cb.cache.offset, 0);

    /*
     * see if we have a cache hit. we will have a cache hit iff:
     *
     * for MAP_ANY, minimum one byte, or *lenp, or len_avail in cache:
     *
     *    cache.offset <= offset < (cache.offset + cache.len)
     *
     * for MAP_ALL, *lenp bytes of data are in cache:
     *
     *    cache.offset <= (offset + *lenp) < (cache.offset + cache.len)
     *
     * Conditions for returning successful dblk data mapping are:
     * - cache is valid AND
     * - offset is greater than start of cache (cache.offset) AND
     *   - if MAP_ALL
     *     - offset + size is less than or equal to end of cache
     *        (cache.offset + cache.len)
     *   - if MAP_ANY
     *     - offset is less than end of cache (cache.offset + cache.len)
     * success means that some or all requested data is available in cache
     */
    if (dmf_cb.cache.len &&
        (dmf_cb.cache.offset <= offset) &&
        (((map_mode == MAP_ALL) &&
          ((offset + *lenp) <= (dmf_cb.cache.offset + dmf_cb.cache.len))) ||
         ((map_mode == MAP_ANY) &&
          (offset < (dmf_cb.cache.offset + dmf_cb.cache.len))))) {
      *bufp = &dmf_cache[(offset - dmf_cb.cache.offset)];

      /* check and possibly modify how much data we can make available */
      len_avail = (dmf_cb.cache.offset + dmf_cb.cache.len) - offset;
      if (len_avail < *lenp) {
        if (map_mode == MAP_ALL)
          // shouldn't get here because of conditional tests above
          dmap_panic(5, len_avail, *lenp);
        *lenp = len_avail;
      }
      return SUCCESS;
    }

    /*
     * Cache Miss, first need to preserve any cached data required
     * for MAP_ALL mode request with data spanning sector boundary.
     * the partial match in this sector is copied to the beginning
     * of the cache and immediately followed.
     * Otherwise, cache is empty so set cache.len to zero and
     * cache.offset to block which holds the requested offset.
     *
     * Only fill the cache when the data requested (offset + *lenp)
     * is just straddling the SD block boundary by one word at
     * at the end. This ensures cache is only filled once since
     * sync search is going to walk through map at quad boundary
     * while asking for sizeof(dt_sync_t).
     */
    if ((map_mode == MAP_ALL) &&
        (dmf_cb.cache.offset <= offset) &&
        (offset < (dmf_cb.cache.offset + dmf_cb.cache.len)) &&
        (((offset + *lenp - sizeof(uint32_t)) % SD_BLOCKSIZE) == 0)) {
      dmf_cb.cache.len = dmf_cb.cache.offset + dmf_cb.cache.len - RNDWORDDN(offset);
      copy_block(
        /* where partial data starts, rounded down to quad aligned */
        (uint32_t *) &dmf_cache[RNDWORDDN(offset) - dmf_cb.cache.offset],
        /* put data at beginning of cache */
        (uint32_t *) &dmf_cache[0],
        /* amount to copy is size from requested offset to end of cache */
        dmf_cb.cache.len);
      dmf_cb.cache.offset = RNDWORDDN(offset);
    } else {
      dmf_cb.cache.len = 0; /* nothing in cache */
      dmf_cb.cache.offset = RNDBLKDN(offset);
    }
    dmf_cb.cache.id = 0;     /* invalidate blk_id currently in cache*/

    /*
     * Check Stream Storage where more data is located, stream
     * buffer or disk, or end of file.
     */
    blk_id = call SS.where(context,
                           RNDWORDDN(offset) + dmf_cb.cache.len,
                           &len,
                           &blk_offset,
                           &blk_buf);
    if (!blk_id) {                      /* past eof   */
      *bufp = NULL;                     /* no result  */
      *lenp = 0;                        /* no result  */
      return EODATA;
    }

    /* make sure new data is what we expected in cache alignment */
    if (blk_offset != (dmf_cb.cache.offset + dmf_cb.cache.len))
      dmap_panic(6, blk_offset, dmf_cb.cache.offset + dmf_cb.cache.len);

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
     * (need account for any data preserved in cache earlier)
     */
    if (blk_buf) {
      if ((dmf_cb.cache.len + len) > CACHE_SIZE)
        dmap_panic(7, dmf_cb.cache.len, len);
      dmf_cb.cache.len += copy_block((uint32_t *) blk_buf,
                                     (uint32_t *) &dmf_cache[dmf_cb.cache.len],
                                     len);
      dmf_cb.cache.id     = blk_id;
      /* set bufp return value to address in cache for requested byte offset */
      *bufp = &dmf_cache[(offset - dmf_cb.cache.offset)];

      /* check and possibly modify how much data we can make available */
      len_avail = dmf_cb.cache.offset + dmf_cb.cache.len - offset;
      if (len_avail < *lenp){
        if (map_mode == MAP_ALL) {
          /* the only way for length to be less than 512 is the last
           * valid block in Stream buffers */
          if (len < SD_BLOCKSIZE) {
            *bufp = NULL;
            *lenp = 0;
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
    if (dmf_cb.cache.len % CACHE_WORD) // panic if not word aligned
      dmap_panic(5, dmf_cb.cache.len, blk_id);
    if ((sizeof(dmf_cache) - dmf_cb.cache.len) < SD_BLOCKSIZE) // panic if buf too small
      dmap_panic(7, dmf_cb.cache.len, sizeof(dmf_cache));
    dmf_cb.fill_blk_id  = blk_id;
    dmf_cb.ready        = FALSE;
    dmf_cb.requested    = FALSE;
    dmf_cb.reading      = FALSE;
    dmf_cb.err = call SDResource.request();
    if (dmf_cb.err != SUCCESS) {
      dmap_panic(6, dmf_cb.err, 0);
      dmf_cb.fill_blk_id  = 0;
      return FAIL;
    }
    dmf_cb.requested   = TRUE;
    return EBUSY;
  }


  command error_t DMF.map(uint32_t context, uint8_t **bufp,
                          uint32_t offset, uint32_t *lenp) {
    return mapit(context, bufp, offset, lenp, MAP_ANY);
  }


  command error_t DMF.mapAll(uint32_t context, uint8_t **bufp,
                          uint32_t offset, uint32_t *lenp) {
    return mapit(context, bufp, offset, lenp, MAP_ALL);
  }


  event void SDResource.granted() {
    dmf_cb.requested = FALSE;
    dmf_cb.err = call SDread.read(dmf_cb.fill_blk_id, &dmf_cache[dmf_cb.cache.len]);
    if (dmf_cb.err) {
      dmap_panic(8, dmf_cb.err, 0);
      dmf_cb.fill_blk_id = 0;
      call SDResource.release();
      signal DMF.data_avail(dmf_cb.err);
      return;
    }
    dmf_cb.reading = TRUE;
    return;
  }


  event void SDread.readDone(uint32_t blk_id, uint8_t *read_buf, error_t err) {
    if (blk_id != dmf_cb.fill_blk_id ||  // panic if wrong read completed
        read_buf != &dmf_cache[dmf_cb.cache.len] || err)
      dmap_panic(9, err, blk_id);
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
    dmf_cb.cache.id   = blk_id;
    dmf_cb.cache.len += SD_BLOCKSIZE;  /* and add sector to cache size */
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
