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

typedef struct {
  uint32_t             base;         // first sector of panic file
  uint32_t             eof;          // last sector with valid data
  uint32_t             cur;          // current sector in sbuf
} panic_map_sectors_t;

typedef struct {
  uint32_t             file_pos;     // current file offset (pos)
  panic_map_sectors_t  sector;       // pertinent file sector numbers
  uint8_t              slot_idx;     // index selects which panic file
  error_t              err;          // last error encountered
  bool                 sbuf_ready;   // true if sbuf contains valid data
  bool                 sbuf_requesting; // true if sd.request in progress
  bool                 sbuf_reading; // true if sd.read in progress
} panic_map_file_t;


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
  panic_map_file_t     pmf_cb;
  uint8_t              pmf_sbuf[SD_BLOCKSIZE] __attribute__ ((aligned (4)));

  inline void pmap_panic(uint8_t where, parg_t p0, parg_t p1) {
    call Panic.panic(PANIC_TAGNET, where, p0, p1, pmf_cb.sector.base,
                     pmf_cb.sector.eof);
  }


  /*
   * return TRUE if the panic slot is not used.
   *
   * The Panic dir holds the next index to write.  All indicies
   * below PanicIndex are used and have something in them.
   */
  bool is_idx_unused(uint8_t slot_idx) {
    return (slot_idx >= call PanicManager.getPanicIndex());
  }


  uint32_t sector_of(uint8_t slot_idx, uint32_t pos) {
    uint32_t   sect, max_sect;

    if (is_idx_unused(slot_idx))
      return 0;
    sect = pos / SD_BLOCKSIZE;
    max_sect =  call PanicManager.getPanicSize();
    if (sect >= max_sect)
      sect = max_sect - 1;
    return (sect + call PanicManager.panicIndex2Sector(slot_idx));
  }

  uint32_t offset_of(uint8_t slot_idx, uint32_t pos) {
    return (pos % SD_BLOCKSIZE);
  }

  uint32_t remaining(uint8_t slot_idx, uint32_t pos) {
    if (is_idx_unused(slot_idx))
      return 0;
    return (SD_BLOCKSIZE - offset_of(slot_idx, pos));
  }

  uint32_t eof_pos(uint8_t slot_idx) {
    if (is_idx_unused(slot_idx))
        return 0;
    return (call PanicManager.getPanicSize() * SD_BLOCKSIZE);
  }

  bool is_eof(uint8_t slot_idx, uint32_t pos) {
    if (pos >= eof_pos(slot_idx))
      return TRUE;
    return FALSE;
  }

  bool inbounds(uint8_t slot_idx, uint32_t pos) {
    /* validate reasonablness */
    if (is_idx_unused(slot_idx))                        return FALSE;
    if (is_eof(slot_idx, pos))                          return FALSE;
    if (sector_of(slot_idx, pos) != pmf_cb.sector.cur)  return FALSE;
    return TRUE;
  }

  bool _get_new_sector(uint32_t slot_idx, uint32_t pos) {
    if (is_idx_unused(slot_idx))
        return FALSE;
    pmf_cb.slot_idx          = slot_idx;
    pmf_cb.sector.base       = sector_of(slot_idx, 0);
    pmf_cb.sector.eof        = sector_of(slot_idx, eof_pos(slot_idx));
    pmf_cb.sector.cur        = sector_of(slot_idx, pos);
    pmf_cb.file_pos          = pos;

    pmf_cb.sbuf_ready        = FALSE;
    pmf_cb.sbuf_requesting   = TRUE;
    pmf_cb.sbuf_reading      = FALSE;

    /*
     * we are about to read the first sector of the panic block
     * range check it against the panic limits.  If outside something
     * is very wrong.  Whatever do don't hang the system.
     */
    if (pmf_cb.sector.cur < call PanicManager.getPanicBase() ||
        pmf_cb.sector.cur > call PanicManager.getPanicLimit())
      pmap_panic(TAGNET_AUTOWHERE, 0, 0);              /* no return */
    pmf_cb.err = call SDResource.request();
    if (pmf_cb.err == SUCCESS)
      return TRUE;
    pmf_cb.sbuf_requesting   = FALSE;
    return FALSE;
  }


  event void SDResource.granted() {
    pmf_cb.sbuf_requesting = FALSE;
    pmf_cb.sbuf_reading    = TRUE;
    call SDread.read(pmf_cb.sector.cur, pmf_sbuf);
  }


  event void SDread.readDone(uint32_t blk_id, uint8_t *read_buf, error_t err) {
    call SDResource.release();
    pmf_cb.sbuf_ready        = TRUE;
    pmf_cb.sbuf_requesting   = FALSE;
    pmf_cb.sbuf_reading      = FALSE;
    signal PMF.data_avail(SUCCESS);
  }


  command error_t PMF.map(uint32_t context, uint8_t **bufp,
                          uint32_t offset, uint32_t *lenp) {
    uint32_t count  = 0;

    if (is_idx_unused(context))
      return EODATA;

    if (pmf_cb.sbuf_ready) {
      if (context != pmf_cb.slot_idx)
        return EINVAL;          /* need to seek first */
      count = (*lenp > remaining(context, pmf_cb.file_pos))
        ? remaining(context, pmf_cb.file_pos) : *lenp;
      *bufp = &pmf_sbuf[offset_of(context, pmf_cb.file_pos)];
      *lenp = count;
      pmf_cb.file_pos += count;
      if (!is_eof(context, pmf_cb.file_pos) &&
          (remaining(context, pmf_cb.file_pos) == 0))
        if (!_get_new_sector(context, pmf_cb.file_pos))
          return FAIL;
      return SUCCESS;
    }
    return EBUSY;
  }


  command uint32_t PMF.filesize(uint32_t context) {
    return eof_pos(context);
  }


  command uint32_t PMF.commitsize(uint32_t context) {
    return eof_pos(context);
  }


  event void PanicManager.populateDone(error_t err) {
    pmf_cb.file_pos = 0;
    pmf_cb.err = err;
    if (err && err != EODATA)
      pmap_panic(TAGNET_AUTOWHERE, err, 0);
    _get_new_sector(0, pmf_cb.file_pos);
  }

  event void Boot.booted() {
    call PanicManager.populate();
  }

  async   event void Panic.hook() { }
  default event void PMF.data_avail(error_t err) { };
}
