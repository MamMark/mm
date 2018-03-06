/**
 * @Copyright (c) 2017 Daniel J. Maltbie
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
    interface ByteMapFile;
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


  event void ByteMapFile.data_avail(error_t err) { }
  event void ByteMapFile.extended(uint32_t context, uint32_t offset)  { }
  event void ByteMapFile.committed(uint32_t context, uint32_t offset) { }
  async event void Panic.hook() { }
}
