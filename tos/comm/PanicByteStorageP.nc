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
#include <mm_byteswap.h>
#include <message.h>
#include <Tagnet.h>
#include <TagnetAdapter.h>

module PanicByteStorageP {
  provides {
    interface  TagnetAdapter<tagnet_file_bytes_t>  as PanicBytes;
  }
  uses {
    interface ByteMapFile  as ByteMapFile;
    interface Boot;
    interface Panic;
  }
}
implementation {

  command bool PanicBytes.get_value(tagnet_file_bytes_t *db, uint32_t *len) {
    nop();
    nop();                      /* BRK */
    db->error  = EINVAL;

    switch (db->action) {
      case FILE_GET_DATA:
        db->error = call ByteMapFile.seek(db->file, db->iota, 0);
        if (db->error == SUCCESS) {
          db->error = call ByteMapFile.map(db->file, &db->block, len);
        }
        if (db->error == SUCCESS) {
          db->iota   = call ByteMapFile.tell(db->file);
          db->count -= *len;
          return TRUE;
        }
        break;
      case  FILE_GET_ATTR:
        db->iota   = call ByteMapFile.tell(db->file);
        db->count  = call ByteMapFile.filesize(db->file);
        return TRUE;
      default:
        break;
    }
    db->iota = call ByteMapFile.tell(db->file);
    *len = 0;
    db->count = 0;
    return TRUE;
  }


  command bool PanicBytes.set_value(tagnet_file_bytes_t *db, uint32_t *len) {
    db->count = 0;
    db->error = EINVAL;
    *len = 0;
    return FALSE;
  }


  event void ByteMapFile.mapped(uint8_t fd, uint32_t file_pos) {
    nop();
    nop();                            /* BRK */
  }


  async event void Panic.hook() { }


  event void Boot.booted() {
    nop();
    nop();                            /* BRK */
  }
}
