/**
 * This module handles Byte access to the Panic storage files
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
  uint32_t             base;         // first sector of panic file
  uint32_t             eof;          // last sector with valid data
  uint32_t             cur;          // current sector in sbuf
} panic_map_sectors_t;

typedef struct {
  uint32_t             file_pos;     // current file position
  panic_map_sectors_t  sector;       // pertinent file sector numbers
  uint8_t              fileno;       // index selects which panic file
  error_t              err;          // last error encountered
  bool                 sbuf_ready;   // true if sbuf contains valid data
  bool                 sbuf_requesting; // true if sd.request in progress
  bool                 sbuf_reading; // true if sd.read in progress
} panic_map_file_t;

module PanicMapFileP {
  provides  interface ByteMapFile              as ByteMapFile;
  uses      interface PanicManager             as PanicManager;
  uses      interface SDread                   as SDread;
  uses      interface Resource                 as SDResource;
  uses      interface Boot;
  uses      interface Panic;
}
implementation {
  panic_map_file_t     pmf_cb;
  uint8_t              pmf_sbuf[SD_BLOCKSIZE] __attribute__ ((aligned (4)));

  void pmap_panic(uint8_t where, parg_t p0, parg_t p1) {
    call Panic.panic(PANIC_TAGNET, where, p0, p1, pmf_cb.sector.base,
                     pmf_cb.sector.eof);
  }

  bool is_fd_full(uint8_t fd) {
    return (fd < call PanicManager.getPanicIndex());
  }

  bool is_fd_valid(uint8_t fd) {
    return (fd < call PanicManager.getMaxPanicIndex());
  }

  uint32_t sector_of(uint8_t fd, uint32_t pos) {
    uint32_t   sect, max_sect;

    if (!is_fd_full(fd))
      return 0;
    sect = pos / SD_BLOCKSIZE;
    max_sect =  call PanicManager.getPanicSize();
    if (sect >= max_sect)
      sect = max_sect - 1;
    return (sect + call PanicManager.panicIndex2Sector(fd));
  }

  uint32_t offset_of(uint8_t fd, uint32_t pos) {
    return (pos % SD_BLOCKSIZE);
  }

  uint32_t fpos_of(uint8_t fd, uint32_t sect) {
    uint32_t  s_base, s_eof;

    if (!is_fd_full(fd))
      return 0;
    s_base = call PanicManager.panicIndex2Sector(fd);
    s_eof  = s_base + call PanicManager.getPanicSize();
    if ((sect < s_base) || (sect > s_eof)) {
      pmap_panic(1, sect, s_base);
      return 0;
    }
    return ((sect - s_base) * SD_BLOCKSIZE);
  }

  uint32_t remaining(uint8_t fd, uint32_t pos) {
    if (!is_fd_full(fd))
      return 0;
    return (SD_BLOCKSIZE - offset_of(fd, pos));
  }

  uint32_t eof_pos(uint8_t fd) {
    return (call PanicManager.getPanicSize() * SD_BLOCKSIZE);
  }

  bool is_eof(uint8_t fd, uint32_t pos) {
    if (pos >= eof_pos(fd))
      return TRUE;
    return FALSE;
  }

  bool inbounds(uint8_t fd, uint32_t pos) {
    if (is_fd_full(fd) && !is_eof(fd, pos) &&            \
        (sector_of(fd, pos) == pmf_cb.sector.cur))
      return TRUE;
    return FALSE;
  }

  bool not_ready() {
    // initialization of PanicManager is split phase, so
    // special value of fileno signifies still waiting.
    return (pmf_cb.fileno == 255);
  }

  bool _get_new_sector(uint8_t fd, uint32_t pos) {
    // not protected. caller must ensure that SDResource request is not
    // already pending.
    pmf_cb.fileno            = fd;
    pmf_cb.sector.base       = sector_of(fd, 0);
    pmf_cb.sector.eof        = sector_of(fd, eof_pos(fd));
    pmf_cb.sector.cur        = sector_of(fd, pos);
    pmf_cb.file_pos          = pos;

    pmf_cb.sbuf_ready        = FALSE;
    pmf_cb.sbuf_requesting   = TRUE;
    pmf_cb.sbuf_reading      = FALSE;

    pmf_cb.err = call SDResource.request();
    if (pmf_cb.err == SUCCESS)
      return TRUE;
    pmf_cb.sbuf_requesting   = FALSE;
    return FALSE;
  }

  event void SDResource.granted() {
    if ((!pmf_cb.sbuf_ready) && (pmf_cb.sector.cur)) {
      nop();
      nop();                      /* BRK */
      pmf_cb.sbuf_requesting = FALSE;
      pmf_cb.sbuf_reading    = TRUE;
      call SDread.read(pmf_cb.sector.cur, pmf_sbuf);
    }
  }

  event void SDread.readDone(uint32_t blk_id, uint8_t *read_buf, error_t err) {
    call SDResource.release();
    pmf_cb.sbuf_ready        = TRUE;
    pmf_cb.sbuf_requesting   = FALSE;
    pmf_cb.sbuf_reading      = FALSE;
    signal ByteMapFile.mapped(pmf_cb.fileno, pmf_cb.file_pos);
  }

  command error_t ByteMapFile.map(uint8_t fd, uint8_t **buf, uint32_t *len) {
    uint32_t    count  = 0;

    nop();
    nop();                      /* BRK */
    if (not_ready())
      return EBUSY;
    if (!is_fd_full(fd))
      return EODATA;

    if (pmf_cb.sbuf_ready) {
      if (fd != pmf_cb.fileno)
        return EINVAL;          /* need to seek first */
      count = (*len > remaining(fd, pmf_cb.file_pos)) \
        ? remaining(fd, pmf_cb.file_pos)              \
        : *len;
      *buf = &pmf_sbuf[offset_of(fd, pmf_cb.file_pos)];
      *len = count;
      pmf_cb.file_pos += count;
      if (!is_eof(fd, pmf_cb.file_pos) &&                  \
          (remaining(fd, pmf_cb.file_pos) == 0))
        if (!_get_new_sector(fd, pmf_cb.file_pos))
          return FAIL;
      return SUCCESS;
    }
    return EBUSY;
  }

  command error_t ByteMapFile.seek(uint8_t fd, uint32_t pos, bool from_rear) {
    nop();
    nop();                      /* BRK */

    if (not_ready())
      return EBUSY;
    if (!is_fd_full(fd))
      return EODATA;

    pmf_cb.fileno = fd;
    if (is_eof(fd, pos))
        pos = eof_pos(fd);

    if (from_rear) pmf_cb.file_pos = eof_pos(fd) - pos;
    else           pmf_cb.file_pos = pos;
    if (pmf_cb.sbuf_ready) {
      if (inbounds(fd, pmf_cb.file_pos))
        return SUCCESS;
      nop();                      /* BRK */
      if (is_eof(fd, pmf_cb.file_pos))
        return EODATA;
      if (!_get_new_sector(fd, pmf_cb.file_pos))
        return FAIL;
    }
    return EBUSY;
  }

  command uint32_t ByteMapFile.tell(uint8_t fd) {
    if (not_ready())
      return 0;
    if (fd != pmf_cb.fileno)
      return 0;
    return pmf_cb.file_pos;
  }

  default event void ByteMapFile.mapped(uint8_t fd, uint32_t file_pos) { };

  command uint32_t ByteMapFile.filesize(uint8_t fd) {
    if (not_ready())
      return 0;
    return eof_pos(fd);
  }

  async event void Panic.hook() { }

  event void PanicManager.populateDone(error_t err) {
    pmf_cb.err = err;
    if (err)
      pmap_panic(4, err, 0);
    _get_new_sector(0, pmf_cb.file_pos);
  }

  event void Boot.booted() {
    nop();
    nop();                      /* BRK */
    pmf_cb.fileno           = 255;
    pmf_cb.sector.base      = 0;
    pmf_cb.sector.eof       = 0;
    pmf_cb.sector.cur       = 0;
    pmf_cb.file_pos         = 0;
    pmf_cb.sbuf_ready       = FALSE;
    pmf_cb.sbuf_requesting  = FALSE;
    pmf_cb.sbuf_reading     = FALSE;
    call PanicManager.populate();
  }
}
