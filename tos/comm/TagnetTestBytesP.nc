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

  uint32_t  drop_cnt;   // number of bytes dropped since start of test
  uint8_t   zeros[256]; // zero data pattern
  uint32_t  zero_cnt;   // number of zero bytes correctly received
  uint8_t   ones[256];  // ones data pattern
  uint32_t  ones_cnt;   // number of ones bytes correctly received
  uint8_t   echo[256];  // echo data pattern (received in put, returned in get)
  uint32_t  echo_len;   // length of stored echo pattern
  uint32_t  echo_cnt;   // number of echo bytes sent

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

  /*
   * TestZeroBytes
   *
   * Send/receive Zeros data pattern.
   *
   */
  command bool TestZeroBytes.get_value(tagnet_file_bytes_t *db, uint32_t *lenp) {
    if (!db || !lenp)
      call Panic.panic(0, 0, 0, 0, 0, 0);
    switch (db->action) {
      case FILE_GET_DATA:
        if (*lenp > sizeof(zeros))
          *lenp = sizeof(zeros);
        zero_cnt += *lenp;
        return update_block(db, zeros, SUCCESS, *lenp);
      case FILE_GET_ATTR:
        db->block = NULL;
        db->error = SUCCESS;
        db->iota = zero_cnt;
        db->count = zero_cnt;
        *lenp = 0;
        return TRUE;
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
        if (db->block) {
          for (idx = 0; idx < *lenp; idx++) {
            if (db->block[idx] != 0) {
              err = EINVAL;
              break;
            }
          }
          zero_cnt += *lenp;
        } else {
          zero_cnt = 0;
        }
        *lenp = 0;  // no bytes to return
        return update_block(db, NULL, err, zero_cnt);
      default:
        break;
    }
    db->error = SUCCESS;            /* don't respond, ignore */
    *lenp = 0;
    return FALSE;
  }

  /*
   * TestOnesBytes
   *
   * Send/receive Ones data pattern.
   *
   */
  command bool TestOnesBytes.get_value(tagnet_file_bytes_t *db, uint32_t *lenp) {
    if (!db || !lenp)
      call Panic.panic(0, 0, 0, 0, 0, 0);
    switch (db->action) {
      case FILE_GET_DATA:
        if (*lenp > sizeof(ones))
          *lenp = sizeof(ones);
        ones_cnt += *lenp;
        return update_block(db, ones, SUCCESS, *lenp);
      case FILE_GET_ATTR:
        db->block = NULL;
        db->error = SUCCESS;
        db->iota = ones_cnt;
        db->count = ones_cnt;
        *lenp = 0;
        return TRUE;
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
        if (db->block) {
          for (idx = 0; idx < *lenp; idx++) {
            if (db->block[idx] != 0xff) {
              err = EINVAL;
              break;
            }
          }
          ones_cnt += *lenp;
        } else {
          ones_cnt = 0;
        }
        *lenp = 0;  // no bytes to return
        return update_block(db, NULL, err, ones_cnt);
      default:
        break;
    }
    db->error = SUCCESS;            /* don't respond, ignore */
    *lenp = 0;
    return FALSE;
  }

  /*
   * TestEchoBytes
   *
   * Send/Receive user specified data pattern.
   *
   */
  command bool TestEchoBytes.get_value(tagnet_file_bytes_t *db, uint32_t *lenp) {
    if (!db || !lenp)
      call Panic.panic(0, 0, 0, 0, 0, 0);
    switch (db->action) {
      case FILE_GET_DATA:
        if (*lenp > echo_len)
          *lenp = echo_len;
        echo_cnt += *lenp;
        return update_block(db, echo, SUCCESS, *lenp);
      case FILE_GET_ATTR:
        db->block = NULL;
        db->error = SUCCESS;
        db->iota = echo_cnt;
        db->count = echo_cnt;
        *lenp = 0;
        return TRUE;
      default:
        break;
    }
    db->error = SUCCESS;            /* don't respond, ignore */
    *lenp = 0;
    return FALSE;
  }

  command bool TestEchoBytes.set_value(tagnet_file_bytes_t *db, uint32_t *lenp) {
    uint32_t  idx;

    if (!db || !lenp)
      call Panic.panic(0, 0, 0, 0, 0, 0);
    switch (db->action) {
      case FILE_SET_DATA:
        if (db->block) {
          if (*lenp > sizeof(echo))
            *lenp = sizeof(echo);
          for (idx = 0; idx < *lenp; idx++)
            echo[idx] = db->block[idx];
          echo_len = idx;
        } else {
          echo_cnt = 0;
        }
        *lenp = 0;  // no bytes to return
        return update_block(db, NULL, SUCCESS, echo_len);
      default:
        break;
    }
    db->error = SUCCESS;            /* don't respond, ignore */
    *lenp = 0;
    return FALSE;
  }

  /*
   * TestDropBytes
   *
   * Drop received message.
   *
   */
  command bool TestDropBytes.get_value(tagnet_file_bytes_t *db, uint32_t *lenp) {
    if (!db || !lenp)
      call Panic.panic(0, 0, 0, 0, 0, 0);
    switch (db->action) {
      case FILE_GET_ATTR:
        db->block = NULL;
        db->error = SUCCESS;
        db->iota = drop_cnt;
        db->count = drop_cnt;
        *lenp = 0;
        return TRUE;
      default:
        break;
    }
    db->error = SUCCESS;            /* don't respond, ignore */
    *lenp = 0;
    return FALSE;
  }

  command bool TestDropBytes.set_value(tagnet_file_bytes_t *db, uint32_t *lenp) {
    if (!db || !lenp)
      call Panic.panic(0, 0, 0, 0, 0, 0);
    switch (db->action) {
      case FILE_SET_DATA:
        if (db->block) {
          drop_cnt += *lenp;
          db->block = NULL;
          db->error = SUCCESS;
          db->iota = drop_cnt;
          db->count = drop_cnt;
        } else {
          drop_cnt = 0;
        }
        *lenp = 0;
        return TRUE;
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
