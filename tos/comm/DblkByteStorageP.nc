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
#include <Tagnet.h>
#include <TagnetAdapter.h>

module DblkByteStorageP {
  provides {
    interface  TagnetAdapter<tagnet_file_bytes_t>  as DblkBytes;
    interface  TagnetAdapter<tagnet_dblk_note_t>   as DblkNote;
  }
  uses {
    interface ByteMapFileNew as DMF;
    interface Collect;
    interface Panic;
  }
}
implementation {

  uint32_t   dblk_notes_count = 0;

  bool GetDblkBytes(tagnet_file_bytes_t *db, uint32_t *lenp) {
    switch (db->action) {
      case FILE_GET_DATA:
        db->error = call DMF.map(db->context, &db->block, db->iota, lenp);
        if (db->error == SUCCESS) {
          db->iota     += *lenp;
          db->count    -= *lenp;
          return TRUE;
        }
        *lenp = 0;
        return TRUE;
      case  FILE_GET_ATTR:
        db->count  = call DMF.filesize(db->context);
        return TRUE;
      default:
        db->error = EINVAL;
        return TRUE;
    }
  }

  command bool DblkBytes.get_value(tagnet_file_bytes_t *db, uint32_t *lenp) {
    return GetDblkBytes(db, lenp);
  }

  command bool DblkBytes.set_value(tagnet_file_bytes_t *db, uint32_t *lenp) {
    db->error = EINVAL;
    *lenp = 0;
    return FALSE; }

  command bool DblkNote.get_value(tagnet_dblk_note_t *db, uint32_t *lenp) {
    *lenp = 0;
    db->count  = dblk_notes_count;
    if (db->action == FILE_GET_ATTR) {
      db->error  = SUCCESS;
      *lenp      = db->count;
      return TRUE;
    }
    db->error = EINVAL;
    return FALSE;
  }


  command bool DblkNote.set_value(tagnet_dblk_note_t *db, uint32_t *lenp) {
    dt_note_t    note_block;

    if (db->action == FILE_SET_DATA) {
      ++dblk_notes_count;
      note_block.len = *lenp + sizeof(note_block);
      note_block.dtype = DT_NOTE;
      note_block.note_len = *lenp;
      call Collect.collect((void *) &note_block, sizeof(note_block),
                           db->block, *lenp);
      db->error  = SUCCESS;
      db->count  = note_block.note_len;
      return TRUE;
    }
    db->error = EINVAL;
    return FALSE;
  }


  event void DMF.data_avail(error_t err) { }
        event void DMF.extended(uint32_t context, uint32_t offset)  { }
        event void DMF.committed(uint32_t context, uint32_t offset) { }
  async event void Panic.hook() { }
}
