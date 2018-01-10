/**
 * This module handles Byte access to the Dblk storage files
 *
 *<p>
 * @author Daniel J. Maltbie <dmaltbie@daloma.org>
 *
 * @Copyright (c) 2017 Daniel J. Maltbie
 * All rights reserved.
 *</p>
 */
/* Redistribution and use in source and binary forms, with or without
 * modification, are permitted provided that the following conditions
 * are met:
 *
 * - Redistributions of source code must retain the above copyright
 *   notice, this list of conditions and the following disclaimer.
 *
 * - Redistributions in binary form must reproduce the above copyright
 *   notice, this list of conditions and the following disclaimer in the
 *   documentation and/or other materials provided with the
 *   distribution.
 *
 * - Neither the name of the copyright holders nor the names of
 *   its contributors may be used to endorse or promote products derived
 *   from this software without specific prior written permission.
 *
 * THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS
 * "AS IS" AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT
 * LIMITED TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS
 * FOR A PARTICULAR PURPOSE ARE DISCLAIMED.  IN NO EVENT SHALL
 * THE COPYRIGHT HOLDER OR CONTRIBUTORS BE LIABLE FOR ANY DIRECT,
 * INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES
 * (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR
 * SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION)
 * HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT,
 * STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE)
 * ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED
 * OF THE POSSIBILITY OF SUCH DAMAGE.
 */
#include <TinyError.h>
#include <panic.h>
#include <platform_panic.h>
#include <sd.h>

typedef struct {
  uint32_t             base;         // first sector of dblk file
  uint32_t             eof;          // last sector with valid data
  uint32_t             cur;          // current sector in sbuf
} dblk_map_sectors_t;

typedef struct {
  uint32_t             file_pos;     // current file position
  dblk_map_sectors_t   sector;       // pertinent file sector numbers
  bool                 sbuf_ready;   // true if sbuf has valid data
  bool                 sbuf_reading; // true if read in progress
} dblk_map_file_t;

module DblkMapFileP {
  provides  interface ByteMapFile              as DMF;
  uses      interface StreamStorage            as SS;
  uses      interface SDread                   as SDread;
  uses      interface Resource                 as SDResource;
  uses      interface Boot;
  uses      interface Panic;
}
implementation {
  uint8_t              dmf_sbuf[SD_BLOCKSIZE] __attribute__ ((aligned (4)));
  dblk_map_file_t      dmf_cb;

  void dmap_panic(uint8_t where, parg_t p0, parg_t p1) {
    call Panic.panic(PANIC_DBLK, where, p0, p1, dmf_cb.sector.base, dmf_cb.sector.eof);
  }

  uint32_t sector_of(uint32_t pos) {
    return (pos / SD_BLOCKSIZE) + dmf_cb.sector.base;
  }

  uint32_t offset_of(uint32_t pos) {
    return (pos%SD_BLOCKSIZE);
  }

  uint32_t fpos_of(uint32_t sect) {
    if ((sect < dmf_cb.sector.base) || (sect > dmf_cb.sector.eof)) {
      dmap_panic(1, sect, 0);
      return 0;
    }
    return ((sect - dmf_cb.sector.base) * SD_BLOCKSIZE);
  }

  bool inbounds(uint32_t pos) {
    if (sector_of(pos) == dmf_cb.sector.cur)
      return TRUE;
    return FALSE;
  }

  uint32_t remaining(uint32_t pos) {
    return (SD_BLOCKSIZE - offset_of(pos));
  }

  uint32_t eof_pos() {
    return ((dmf_cb.sector.eof - dmf_cb.sector.base) * SD_BLOCKSIZE);
  }

  bool get_new_sector(uint32_t pos) {
    error_t err;
    if (sector_of(pos) <= dmf_cb.sector.eof) {
      dmf_cb.sbuf_ready = FALSE;
      dmf_cb.sbuf_reading = FALSE;
      dmf_cb.sector.cur = sector_of(pos);
      err = call SDResource.request();
      if (err == SUCCESS) return TRUE;
    }
    return FALSE;
  }

  event void SDResource.granted() {
    if ((!dmf_cb.sbuf_ready) && (dmf_cb.sector.cur)) {
      nop();
      nop();                      /* BRK */
      dmf_cb.sbuf_reading = TRUE;
      call SDread.read(dmf_cb.sector.cur, dmf_sbuf);
    }
  }

  event void SDread.readDone(uint32_t blk_id, uint8_t *read_buf, error_t err) {
    call SDResource.release();
    dmf_cb.sbuf_ready = TRUE;
    dmf_cb.sbuf_reading = FALSE;
    signal DMF.mapped(0, dmf_cb.file_pos);
  }

  command error_t DMF.map(uint8_t fd, uint8_t **buf, uint32_t *len) {
    uint32_t    count  = 0;

    nop();
    nop();                      /* BRK */
    if (dmf_cb.sbuf_ready) {
      count = (*len > remaining(dmf_cb.file_pos))   \
        ? remaining(dmf_cb.file_pos)                \
        : *len;
      *buf = &dmf_sbuf[offset_of(dmf_cb.file_pos)];
      *len = count;
      dmf_cb.file_pos += count;
      if (remaining(dmf_cb.file_pos) == 0)
        get_new_sector(dmf_cb.file_pos);
      return SUCCESS;
    }
    return EBUSY;
  }

  command error_t DMF.seek(uint8_t fd, uint32_t pos, bool from_rear) {

    nop();
    nop();                      /* BRK */
    if (pos > eof_pos()) {
      return EODATA;
    }
    if (from_rear) dmf_cb.file_pos = eof_pos() - pos;
    else           dmf_cb.file_pos = pos;
    if (dmf_cb.sbuf_ready) {
      if (inbounds(dmf_cb.file_pos))
        return SUCCESS;
      else
        get_new_sector(dmf_cb.file_pos);
    }
    return EBUSY;
  }

  command uint32_t DMF.tell(uint8_t fd) {
    return dmf_cb.file_pos;
  }

  default event void DMF.mapped(uint8_t fd, uint32_t file_pos) { };

  event void SS.dblk_advanced(uint32_t last) {
    bool was_zero = (!dmf_cb.sector.eof);

    dmf_cb.sector.eof = last;
    if (was_zero)
      get_new_sector(dmf_cb.file_pos);  // get the first one
  }

  command uint32_t DMF.filesize(uint8_t fd) {
    return ((dmf_cb.sector.eof - dmf_cb.sector.base) * SD_BLOCKSIZE);
  }

  event void SS.dblk_stream_full() { }

  async event void Panic.hook() { }

  event void Boot.booted() {
    nop();
    nop();                      /* BRK */
    dmf_cb.sector.base = call SS.get_dblk_low();
    dmf_cb.sector.eof = 0;
    dmf_cb.file_pos = 0;
    get_new_sector(dmf_cb.file_pos);  // get the first one
  }
}
