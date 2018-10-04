/**
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
 * This module handles Byte access to the Panic storage system.
 */

#include <TinyError.h>
#include <panic.h>
#include <sd.h>
#include <tagnet_panic.h>

typedef enum {
  PMFS_NOT_POP = 0,
  PMFS_IDLE,
  PMFS_REQ,
  PMFS_READ,
} pmf_state_t;

typedef struct {
  uint32_t    cache_blk_id;        // storage block id - 0 if cache invalid
  uint32_t    fill_blk_id;         // block id coming into the cache.
  error_t     err;
  pmf_state_t state;
} pmf_cb_t;


#ifndef PANIC_PAN
enum {
  __pcode_pan = unique(UQ_PANIC_SUBSYS)
};

#define PANIC_PAN __pcode_pan
#endif


module PanicMapFileP {
  provides  interface ByteMapFile as PMF;
  uses {
    interface PanicManager;
    interface SDread;
    interface Resource as SDResource;
    interface Boot;
    interface Panic;
  }
}
implementation {
  pmf_cb_t pmf_cb;
  uint8_t  pmf_cache[SD_BLOCKSIZE] __attribute__ ((aligned (4)));

  inline void pmap_panic(uint8_t where, parg_t p0, parg_t p1) {
    call Panic.panic(PANIC_PAN, where, p0, p1, pmf_cb.cache_blk_id,
                     pmf_cb.fill_blk_id);
  }


  event void SDResource.granted() {
    if (pmf_cb.state != PMFS_REQ || !pmf_cb.fill_blk_id)
      pmap_panic(1, pmf_cb.state, 0);
    pmf_cb.state = PMFS_READ;
    call SDread.read(pmf_cb.fill_blk_id, pmf_cache);
  }


  event void SDread.readDone(uint32_t blk_id, uint8_t *read_buf, error_t err) {
    uint32_t idx;

    if (pmf_cb.state != PMFS_READ || pmf_cb.fill_blk_id != blk_id)
      pmap_panic(2, pmf_cb.state, blk_id);
    call SDResource.release();
    pmf_cb.state = PMFS_IDLE;
    pmf_cb.fill_blk_id = 0;
    pmf_cb.cache_blk_id = blk_id;
    if (blk_id > call PanicManager.getPanicBase()) {
      for (idx = 0; idx < 512; idx++) {
        if (pmf_cache[idx] != (idx & 0xff))
          nop();                        /* BRK */
      }
    }
    signal PMF.data_avail(SUCCESS);
  }


  command error_t PMF.map(uint32_t context, uint8_t **bufp,
                          uint32_t offset, uint32_t *lenp) {
    uint32_t req_blk;                   /* block id being requested */
    uint32_t len_avail;                 /* how much is avail from the cache */

    if (pmf_cb.state != PMFS_IDLE)
      return EBUSY;

    if (!lenp || !bufp)                 /* nulls are very bad */
      pmap_panic(0, 0, 0);

    if (*lenp == 0) {                   /* asking for nothing? */
      *bufp = NULL;                     /* no buffer */
      return EINVAL;                    /* should we return SUCCESS? */
    }

    /*
     * A request looks like a file_offset (offset) and a length (*lenp)
     * convert the offset into its absolute blk id in the panic area
     * and check it against what is in the cache.  We only do whole sectors
     * so if the blk ids match we have a cache hit.
     */

    req_blk = (offset >> SD_BLOCKSIZE_NBITS) + call PanicManager.getPanicBase();
    if (pmf_cb.cache_blk_id == req_blk) {
      *bufp = &pmf_cache[offset % SD_BLOCKSIZE];

      /* check and possibly modify how much data we can make available */
      len_avail = SD_BLOCKSIZE - offset % SD_BLOCKSIZE;
      if (len_avail < *lenp)
        *lenp = len_avail;
      return SUCCESS;
    }

    /* missed, go read req_blk, if it isn't past the EOF */
    if (offset >= call PMF.filesize(context)) {
      *bufp = NULL;
      *lenp = 0;
      return EODATA;
    }

    pmf_cb.cache_blk_id = 0;            /* invalidate */
    pmf_cb.fill_blk_id  = req_blk;
    pmf_cb.state = PMFS_REQ;
    pmf_cb.err = call SDResource.request();
    if (pmf_cb.err != SUCCESS)
      pmap_panic(3, pmf_cb.err, 0);
    return EBUSY;
  }

  command error_t PMF.mapAll(uint32_t context, uint8_t **bufp,
                             uint32_t offset, uint32_t *lenp) {
    pmap_panic(4, offset, *lenp);
  }

  /*
   * PanicMapFile.filesize()
   *
   * return max file offset of any panic blocks that have been written.
   *
   * If no panics written, return 0.
   *
   * Otherwise, return number of panics written (PanicIndex) * PanicSize + Dir.
   * PanicIndex is literally the number of panics already written.  0 indicates
   * no panics written.
   */
  command uint32_t PMF.filesize(uint32_t context) {
    uint32_t idx;

    /*
     * get the next index from PanicManager that will be written
     * NOTE: if the PCB is not populated, getPanicIndex() will return 0.
     */
    idx = call PanicManager.getPanicIndex();
    if (!idx)                           /* if 0, no panics written */
      return 0;

    /*
     * otherwise...
     *
     * account for the directory and all panic blocks written.  This is
     *
     *     SD_BLOCKSIZE * (PanicSize * idx + 1)
     *
     * + 1 is for the directory
     */
    idx = call PanicManager.getPanicSize() * idx + 1;
    idx = idx * SD_BLOCKSIZE;
    return idx;
  }


  command uint32_t PMF.commitsize(uint32_t context) {
    return call PMF.filesize(context);
  }


  event void PanicManager.populateDone(error_t err) {
    pmf_cb.err = err;
    if (err && err != EODATA)
      pmap_panic(5, err, 0);
    pmf_cb.state = PMFS_IDLE;
    pmf_cb.cache_blk_id = 0;            /* no cache loaded */
    pmf_cb.err = err;
  }

  event void Boot.booted() {
    /* pmf_cb.state initial state is 0 (PMFS_NOT_POP) */
    call PanicManager.populate();
  }

  async   event void Panic.hook() { }
  default event void PMF.data_avail(error_t err) { };
}
