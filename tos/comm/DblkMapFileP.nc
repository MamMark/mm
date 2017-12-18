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

module DblkMapFileP {
  provides  interface DblkMapFile;
  uses      interface StreamStorage            as SS;
  uses      interface SDread                   as SDread;
  uses      interface Resource                 as SDResource;
  uses      interface Boot;
  uses      interface Panic;
}
implementation {
  uint32_t             base_sector;
  uint32_t             eof_sector;
  uint32_t             _file_pos;
  bool                 sbuf_valid;
  uint32_t             sbuf_sector;
  uint8_t              sbuf[SD_BLOCKSIZE];

  bool inbounds(uint32_t pos) {
    if ((pos / SD_BLOCKSIZE) == sbuf_sector)
      return TRUE;
    return FALSE;
  }

  uint32_t remaining(uint32_t pos) {
    return (SD_BLOCKSIZE - (pos%SD_BLOCKSIZE));
  }

  uint32_t offset_of(uint32_t pos) {
    return (pos%SD_BLOCKSIZE);
  }

  uint32_t which_sector(uint32_t pos) {
    return (pos / SD_BLOCKSIZE);
  }

  bool get_new_sector(uint32_t pos) {
    error_t err;
    if ((pos / SD_BLOCKSIZE) <= eof_sector) {
      sbuf_valid = FALSE;
      sbuf_sector = which_sector(pos);
      err = call SDResource.request();
      if (err == SUCCESS) return TRUE;
    }
    return FALSE;
  }

  void fake_fill_sbuf(uint32_t val) {
    uint32_t ix;
    for (ix = 0; ix < sizeof(sbuf); ix++)
      sbuf[ix] = val%256;
  }

  event void SDResource.granted() {
    if (!sbuf_valid)
     call SDread.read(sbuf_sector + base_sector, sbuf);
  }

  event void SDread.readDone(uint32_t blk_id, uint8_t *read_buf, error_t err) {
    call SDResource.release();
//    fake_fill_sbuf(which_sector(_file_pos) + 1);
    sbuf_valid = TRUE;
    signal DblkMapFile.mapped(0, _file_pos);
  }

  command error_t DblkMapFile.map(uint8_t fd, uint8_t **buf, uint32_t *len) {
    uint32_t    count  = 0;

    nop();
    nop();                      /* BRK */
    if (sbuf_valid) {
      count = (*len > remaining(_file_pos))   \
        ? remaining(_file_pos)                \
        : *len;
      *buf = &sbuf[offset_of(_file_pos)];
      *len = count;
      _file_pos += count;
      if (remaining(_file_pos) == 0)
        get_new_sector(_file_pos);
      return SUCCESS;
    }
    return EBUSY;
  }

  command error_t DblkMapFile.seek(uint8_t fd, uint32_t pos, bool from_rear) {

    nop();
    nop();                      /* BRK */
    if (pos > (eof_sector * SD_BLOCKSIZE)) {
      return EODATA;
    }
    if (from_rear) _file_pos = (eof_sector * SD_BLOCKSIZE) - pos;
    else           _file_pos = pos;
    if (sbuf_valid) {
      if (inbounds(_file_pos))
        return SUCCESS;
      else
        get_new_sector(_file_pos);
    }
    return EBUSY;
  }

  command uint32_t DblkMapFile.tell(uint8_t fd) {
    return _file_pos;
  }

  default event void DblkMapFile.mapped(uint8_t fd, uint32_t file_pos) { };

  event void SS.dblk_advanced(uint32_t last) {
    eof_sector = last;
  }

  command uint32_t DblkMapFile.filesize(uint8_t fd) {
    return (eof_sector * SD_BLOCKSIZE);
  }

  event void SS.dblk_stream_full() { }

  async event void Panic.hook() { }

  event void Boot.booted() {
    base_sector = call SS.get_dblk_low();
    eof_sector = 0;
    _file_pos = 0;
    get_new_sector(_file_pos);  // get the first one
  }
}
