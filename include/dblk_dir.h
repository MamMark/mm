/*
 * Copyright (c) 2017 Eric B. Decker
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

/*
 * Definitions for the Dblk directory.
 *
 * The Dblk manager controls initialization of the data stream
 * subsystem.
 */

#ifndef __DBLK_DIR_H__
#define __DBLK_DIR_H__

#include <rtctime.h>

#define DBLK_ID_SIZE   4
#define DBLK_DIR_SIG   0x18961492

/*
 * The Dblk Directory
 *
 * Integrity of the directory is enhanced using two signatures and a
 * checksum over the entire directory structure.
 *
 * The checksum is a simple 32 bit wide checksum.
 *
 * dblk_id is the chars DBLK identifing this as a DBLK dir.
 * file_idx indicates which of the n possible DBLK files this
 * DBLK is.  Each DBLK file is a contiguous number of sectors
 * assigned to a FAT file.  Max size is 4Gbytes.  On large
 * SDs we may have more than one.  The first one is named
 * DBLK0001 and has file_idx 1.
 */

#define DBLK_DIR_QUADS 9

typedef struct {                        /* Image Directory */
  uint8_t    dblk_id[DBLK_ID_SIZE];     /* readable string, DBLK */
  uint32_t   dblk_dir_sig;
  uint32_t   dblk_low;
  uint32_t   dblk_high;
  rtctime_t  incept_date;
  uint8_t    file_idx;                  /* file idx */
  uint8_t    pad;
  uint32_t   dblk_dir_sig_a;
  uint32_t   chksum;
} dblk_dir_t;

#endif  /* __DBLK_DIR_H__ */
