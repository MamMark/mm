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
 * @author Daniel J. Maltbie (dmaltbie@daloma.org)
 */

#ifndef __TAGNETADAPTER_H__
#define __TAGNETADAPTER_H__

#include <Tagnet.h>
#include <image_info.h>
#include <image_mgr.h>
#include <si446x_stats.h>

/*
 * GPS Position and Time Information
 */
typedef struct {
  uint32_t                gps_x;
  uint32_t                gps_y;
  uint32_t                gps_z;
} tagnet_gps_xyz_t;

#define TN_GPS_XYZ_LEN (sizeof(tagnet_gps_xyz_t))

/*
 * System Execution Control & Status
 */
typedef struct {
  image_ver_t             ver_id;
  slot_state_t            state;
} tagnet_sys_exec_t;

#define TN_SYS_EXEC_LEN (sizeof(tagnet_sys_exec_t))

typedef enum {
  FILE_GET_DATA        = 0,
  FILE_GET_ATTR        = 1,
  FILE_SET_DATA        = 2,
  LAST_ACTION          = 2,
} file_action_t;

typedef struct {
  uint32_t             context;         /* which thing         */
  uint32_t             iota;            /* where/which/obj idx */
  uint32_t             count;           /* how much            */
  uint8_t             *block;           /* where to put/get it */
  int32_t              error;
  uint16_t             delay;
  file_action_t        action;
} tagnet_file_bytes_t;

#define TN_FILE_BYTES_LEN (sizeof(tagnet_file_bytes_t))

typedef tagnet_file_bytes_t tagnet_dblk_note_t;
typedef tagnet_file_bytes_t tagnet_gps_cmd_t;

//#define TN_DBLK_NOTE_LEN (sizeof(tagnet_dblk_note_t))
//#define TN_GPS_CMD_LEN   (sizeof(tagnet_gps_cmd_t))

typedef struct {
  uint8_t             *block;           /* where to put/get it */
} tagnet_block_t;

#endif   /* __TAGNETADAPTER_H__ */
