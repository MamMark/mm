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
 * This module handles Byte access to the Panic storage files
 */

#include <TinyError.h>
#include <Tagnet.h>
#include <TagnetAdapter.h>

module PanicByteStorageP {
  provides interface  TagnetAdapter<tagnet_file_bytes_t>  as PanicBytes;
  uses {
    interface ByteMapFile as PMF;
    interface Panic;
  }
}
implementation {

  command bool PanicBytes.get_value(tagnet_file_bytes_t *db, uint32_t *lenp) {
    /* data block cells like db->count and db->iota get zero'd on the way in */
    if (!db || !lenp)
      call Panic.panic(0, 0, 0, 0, 0, 0);
    switch (db->action) {
      case FILE_GET_DATA:
        db->error = call PMF.map(db->context, &db->block, db->iota, lenp);
        if (db->error == SUCCESS) {
          db->iota  += *lenp;
          db->count -= *lenp;
          return TRUE;
        }
        *lenp = 0;
        return TRUE;

      case  FILE_GET_ATTR:
        db->count  = call PMF.filesize(db->context);
        *lenp = 0;
        return TRUE;

      default:
        db->error = EINVAL;            /* don't respond, ignore */
        *lenp = 0;
        return FALSE;
    }
  }


  command bool PanicBytes.set_value(tagnet_file_bytes_t *db, uint32_t *lenp) {
    if (!db || !lenp)
      call Panic.panic(0, 0, 0, 0, 0, 0);
    db->error = EINVAL;
    *lenp = 0;
    return FALSE;
  }


        event void PMF.data_avail(error_t err) { }
  async event void Panic.hook() { }
}
