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
 * This module handles Byte access to the Dblk storage files
 */

#include <TinyError.h>
#include <Tagnet.h>
#include <TagnetAdapter.h>

module TagnetTestBytesP {
  provides {
    interface  TagnetAdapter<tagnet_file_bytes_t>  as TestZeroBytes;
    interface  TagnetAdapter<tagnet_file_bytes_t>  as TestOnesBytes;
    interface  TagnetAdapter<tagnet_file_bytes_t>  as TestEchoBytes;
    interface  TagnetAdapter<tagnet_file_bytes_t>  as TestDropBytes;
  }
  uses {
    interface Boot;
    interface Panic;
  }
}
implementation {

  uint8_t zeros[256];
  uint8_t ones[256];
  uint8_t echo[256];
  uint8_t echo_len;

  bool update_block(tagnet_file_bytes_t *db, uint8_t *block, uint32_t err, uint32_t actual) {
    db->block = block;
    db->error = err;
    db->iota += actual;
    if (actual < db->count)
      db->count -= actual;
    else
      db->count = 0;
    return TRUE;
  }

  command bool TestZeroBytes.get_value(tagnet_file_bytes_t *db, uint32_t *lenp) {
    if (!db || !lenp)
      call Panic.panic(0, 0, 0, 0, 0, 0);
    switch (db->action) {
      case FILE_GET_DATA:
        if (*lenp > sizeof(zeros))
          *lenp = sizeof(zeros);
        return update_block(db, zeros, SUCCESS, *lenp);
      default:
        break;
    }
    db->error = SUCCESS;            /* don't respond, ignore */
    *lenp = 0;
    return FALSE;
  }

  command bool TestZeroBytes.set_value(tagnet_file_bytes_t *db, uint32_t *lenp) {
    uint32_t  idx;
    error_t   err;

    if (!db || !lenp)
      call Panic.panic(0, 0, 0, 0, 0, 0);
    switch (db->action) {
      case FILE_SET_DATA:
        err = SUCCESS;
        for (idx = 0; idx < *lenp; idx++) {
          if (db->block[idx] != 0) {
            err = EINVAL;
            break;
          }
        }
        *lenp = 0;  // no bytes to return
        return update_block(db, NULL, err, idx);
      default:
        break;
    }
    db->error = SUCCESS;            /* don't respond, ignore */
    *lenp = 0;
    return FALSE;
  }

  command bool TestOnesBytes.get_value(tagnet_file_bytes_t *db, uint32_t *lenp) {
    if (!db || !lenp)
      call Panic.panic(0, 0, 0, 0, 0, 0);
    switch (db->action) {
      case FILE_GET_DATA:
        if (*lenp > sizeof(ones))
          *lenp = sizeof(ones);
        return update_block(db, ones, SUCCESS, *lenp);
      default:
        break;
    }
    db->error = SUCCESS;            /* don't respond, ignore */
    *lenp = 0;
    return FALSE;
  }

  command bool TestOnesBytes.set_value(tagnet_file_bytes_t *db, uint32_t *lenp) {
    uint32_t  idx;
    error_t   err;

    if (!db || !lenp)
      call Panic.panic(0, 0, 0, 0, 0, 0);
    switch (db->action) {
      case FILE_SET_DATA:
        err = SUCCESS;
        for (idx = 0; idx < *lenp; idx++) {
          if (db->block[idx] != 0xff) {
            err = EINVAL;
            break;
          }
        }
        *lenp = 0;  // no bytes to return
        return update_block(db, NULL, err, idx);
      default:
        break;
    }
    db->error = SUCCESS;            /* don't respond, ignore */
    *lenp = 0;
    return FALSE;
  }

  command bool TestEchoBytes.get_value(tagnet_file_bytes_t *db, uint32_t *lenp) {
    if (!db || !lenp)
      call Panic.panic(0, 0, 0, 0, 0, 0);
    switch (db->action) {
      case FILE_GET_DATA:
        if (*lenp > echo_len)
          *lenp = echo_len;
        return update_block(db, echo, SUCCESS, *lenp);
      default:
        break;
    }
    db->error = SUCCESS;            /* don't respond, ignore */
    *lenp = 0;
    return FALSE;
  }

  command bool TestEchoBytes.set_value(tagnet_file_bytes_t *db, uint32_t *lenp) {
    uint32_t  idx;

    if (!db || !lenp || !db->block)
      call Panic.panic(0, 0, 0, 0, 0, 0);
    switch (db->action) {
      case FILE_SET_DATA:
        if (*lenp > sizeof(echo))
          *lenp = sizeof(echo);
        for (idx = 0; idx < *lenp; idx++)
          echo[idx] = db->block[idx];
        echo_len = idx;
        *lenp = 0;  // no bytes to return
        return update_block(db, NULL, SUCCESS, idx);
      default:
        break;
    }
    db->error = SUCCESS;            /* don't respond, ignore */
    *lenp = 0;
    return FALSE;
  }

  command bool TestDropBytes.get_value(tagnet_file_bytes_t *db, uint32_t *lenp) {
    if (!db || !lenp)
      call Panic.panic(0, 0, 0, 0, 0, 0);
    db->error = SUCCESS;            /* don't respond, ignore */
    *lenp = 0;
    return TRUE;
  }

  command bool TestDropBytes.set_value(tagnet_file_bytes_t *db, uint32_t *lenp) {
    uint32_t idx;

    if (!db || !lenp)
      call Panic.panic(0, 0, 0, 0, 0, 0);
    switch (db->action) {
      case FILE_SET_DATA:
        idx = *lenp;
        *lenp = 0;  // no bytes to return
        return update_block(db, NULL, SUCCESS, idx);
      default:
        break;
    }
    db->error = SUCCESS;            /* don't respond, ignore */
    *lenp = 0;
    return FALSE;
  }

  event void Boot.booted() {
    uint32_t  idx;

    for (idx = 0; idx < sizeof(ones); idx++)
      ones[idx] = 0xff;
  }

  async   event void Panic.hook()          { }
}
