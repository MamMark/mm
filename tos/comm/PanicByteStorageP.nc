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
#include <Tagnet.h>
#include <TagnetAdapter.h>

module PanicByteStorageP {
  provides interface  TagnetAdapter<tagnet_file_bytes_t>  as PanicBytes;
  uses {
    interface ByteMapFileNew as ByteMapFile;
    interface Panic;
  }
}
implementation {

  command bool PanicBytes.get_value(tagnet_file_bytes_t *db, uint32_t *lenp) {
    /* data block cells like db->count and db->iota get zero'd on the way in */
    switch (db->action) {
      default:
        db->error = EINVAL;
        return FALSE;

      case FILE_GET_DATA:
        db->error = call ByteMapFile.map(db->context, &db->block, db->iota, lenp);
        if (db->error == SUCCESS) {
          db->iota  += *lenp;
          db->count -= *lenp;
          return TRUE;
        }
        *lenp = 0;
        return TRUE;

      case  FILE_GET_ATTR:
        db->count  = call ByteMapFile.filesize(db->context);
        return TRUE;
    }
  }


  command bool PanicBytes.set_value(tagnet_file_bytes_t *db, uint32_t *lenp) {
    db->error = EINVAL;
    *lenp = 0;
    return FALSE;
  }


  event void ByteMapFile.data_avail(uint32_t context, uint32_t offset,
                                    uint32_t len) {
    nop();
    nop();                            /* BRK */
  }


  event void ByteMapFile.extended(uint32_t context, uint32_t offset)  { }
  event void ByteMapFile.committed(uint32_t context, uint32_t offset) { }
  async event void Panic.hook() { }
}
