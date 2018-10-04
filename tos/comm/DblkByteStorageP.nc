/**
 * @Copyright (c) 2017 Daniel J. Maltbie
 * @Copyright (c) 2018 Eric B. Decker
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
 * @author Daniel J. Maltbie <dmaltbie@daloma.org>
 */

/**
 * This module handles Byte access to the Dblk storage files
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
    interface ByteMapFile as DMF;
    interface Collect;
    interface Panic;
  }
}
implementation {

  /*
   * Note state.
   *
   * dblk_notes_count is the last note we have seen.  We won't accept
   * the next next note unless it is flagged with the proper iota which
   * needs to be dblk_notes_count + 1.
   *
   * The current notes_count can be obtained by askin DblkNote.get_value
   * which will return dblk_notes_count (ie. the last note we saw)
   */
  uint32_t   dblk_notes_count;          /* inits to 0 */

  command bool DblkBytes.get_value(tagnet_file_bytes_t *db, uint32_t *lenp) {
    if (!db || !lenp)
      call Panic.panic(0, 0, 0, 0, 0, 0);
    switch (db->action) {
      case FILE_GET_DATA:
        db->error = call DMF.map(db->context, &db->block, db->iota, lenp);
        if (db->error == SUCCESS) {
          db->iota  += *lenp;
          db->count -= *lenp;
          return TRUE;
        }
        *lenp = 0;
        return TRUE;

      case  FILE_GET_ATTR:
        db->count  = call DMF.filesize(db->context);
        *lenp = 0;
        return TRUE;

      default:
        db->error = EINVAL;
        *lenp = 0;
        return FALSE;                   /* don't respond, ignore */
    }
  }

  command bool DblkBytes.set_value(tagnet_file_bytes_t *db, uint32_t *lenp) {
    if (!db || !lenp)
      call Panic.panic(0, 0, 0, 0, 0, 0);
    db->error = EINVAL;
    *lenp = 0;
    return FALSE;                       /* no return, don't respond to bs */
  }

  command bool DblkNote.get_value(tagnet_dblk_note_t *db, uint32_t *lenp) {
    if (!db || !lenp)
      call Panic.panic(0, 0, 0, 0, 0, 0);
    *lenp = 0;                          /* no actual content */
    db->iota  = dblk_notes_count;       /* return current state */
    db->count = dblk_notes_count;       /* which is what note we've seen */
    db->error  = SUCCESS;               /* default */
    if (db->action == FILE_GET_ATTR)
      return TRUE;                      /* all good, return above  */
    return FALSE;                       /* otherwise don't respond */
  }


  command bool DblkNote.set_value(tagnet_dblk_note_t *db, uint32_t *lenp) {
    dt_note_t    note_block;

    if (!db || !lenp)
      call Panic.panic(0, 0, 0, 0, 0, 0);
    db->error = SUCCESS;                /* default, ignore */
    if (db->action != FILE_SET_DATA) {
      *lenp = 0;                        /* don't send any data back */
      return FALSE;                     /* ignore */
    }

    if (db->iota != dblk_notes_count + 1) {
      /*
       * if it isn't what we expect, tell the other side we are happy
       * but don't do anything.
       */
      db->iota  = dblk_notes_count;     /* but tell which one we are actually on. */
      db->count = dblk_notes_count;
      db->error = EINVAL;
      *lenp = 0;                        /* don't send any data back */
      return TRUE;
    }

    ++dblk_notes_count;
    note_block.len = *lenp + sizeof(note_block);
    note_block.dtype = DT_NOTE;
    call Collect.collect((void *) &note_block, sizeof(note_block),
                         db->block, *lenp);
    db->count  = dblk_notes_count;
    *lenp = 0;
    return TRUE;
  }


        event void Collect.collectBooted()     { }
        event void DMF.data_avail(error_t err) { }
        event void DMF.extended(uint32_t context, uint32_t offset)  { }
        event void DMF.committed(uint32_t context, uint32_t offset) { }
        event void Collect.resyncDone(error_t err, uint32_t offset) { }
  async event void Panic.hook() { }
}
