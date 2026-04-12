/*
 * Copyright (c) 2020, Eric B. Decker
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
 * Contact: Eric B. Decker <cire831@gmail.com>
 */

#ifndef __DOCKCOMM_H__
#define __DOCKCOMM_H__

#define DC_OVERHEAD 6

typedef struct {
  uint8_t  dc_chn;
  uint8_t  dc_type;
  uint16_t dc_len;
} dc_hdr_t;


/*
 * Channels
 */
enum {
  DC_CHN_NONE           = 0,
  DC_CHN_CORE           = 1,
  DC_CHN_TAGNET         = 2,
  DC_CHN_PRINT          = 3,
  DC_CHN_LARGE_DBLK     = 4,
  DC_CHN_MAX            = 4,
};


enum {
  DC_CORE_HELLO         = 0,
  DC_CORE_ID            = 1,
  DC_CORE_FETCH         = 2,
  DC_CORE_MAX           = 2,
};


/*
 * various SRSP codes, including idle bytes
 */

enum {
  DC_SRSP_OK            = 0,
  DC_SRSP_CHKSUM_ERR    = 1,
  DC_SRSP_PROTO_ERR     = 2,
  DC_SRSP_BUSY          = 3,
  DC_SRSP_REJECT        = 4,
  DC_SRSP_NOMEM         = 5,
  DC_MASTER_IDLE        = 0xfd,
  DC_SLAVE_IDLE         = 0xfe,
  DC_NOONE_HOME         = 0xff,
};


/*
 * abort reasons
 */


#endif          /* __DOCKCOMM_H__ */
