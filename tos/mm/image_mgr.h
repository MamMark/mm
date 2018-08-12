/*
 * Copyright (c) 2017 Eric B. Decker, Miles Maltbie
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
 *          Miles Maltbie <milesmaltbie@gmail.com>
 */

/*
 * Definitions of what the Image Manager Directory Entry looks like
 *
 * The image manager (IM) controls a finite number of image slots
 * that hold Tag images.  Each image is a candidate to be loaded into
 * the NIB region for execution.
 *
 * The directory keeps track of what slots are used and what image is
 * loaded into that slot.  It also keeps track of what the active and
 * backup images are.  The Active is what is currently loaded into the
 * NIB, while the backup is a previously executing image that will be
 * loaded if the Active fails.
 *
 * Images are named by its ver_id.  There can be at most one image
 * loaded with a given ver_id.
 */

#ifndef __IMAGE_MGR_H__
#define __IMAGE_MGR_H__

#include <image_info.h>
#include <sd.h>

/* maximum size image in each slot */
#define IMAGE_SIZE      (128 * 1024)

/*
 * Each image is a maximum of 128KiB, which is exactly
 * 128KiB * (1 sector / 512B) * (1024B/Ki) = 256 sectors
 */
#define IMAGE_SIZE_SECTORS ((IMAGE_SIZE) / (SD_BLOCKSIZE))


/* number of maximum images we support */
#define IMAGE_DIR_SLOTS 4
#define IMAGE_DIR_SIG   0x17254172
#define IMGR_ID_SIZE    4

typedef enum {
  SLOT_EMPTY = 0,
  SLOT_FILLING,                         /* slot is being written */
  SLOT_VALID,                           /* image is valid */
  SLOT_BACKUP,                          /* image is valid and the backup */
  SLOT_ACTIVE,                          /* image is valid and the active */
  SLOT_EJECTED,                         /* image has failed and was ejected */
  SLOT_MAX
} slot_state_t;


/*
 * Directory Slot: each directory slot is controlled by one
 * directory slot entry.
 *
 * ver_id:    the unique name for the image in this slot.
 * start_sec: the absolute blk id where the slot starts.
 * state:     current state of the slot.
 */
typedef struct {                        /* Dir Slot structure   */
  image_ver_t  ver_id;
  uint32_t     start_sec;               /* starting slot sector */
  slot_state_t slot_state;
} image_dir_slot_t;


/*
 * The ImageManager Directory
 *
 * The IM directory lives in the first sector of the Image Area.
 *
 * Integrity of the directory is enhanced using two signatures and a checksum
 * over the entire directory structure.
 *
 * The checksum is a simple 32 bit wide checksum.
 */

typedef struct {                /* Image Directory */
  uint8_t           imgr_id[IMGR_ID_SIZE];      /* readable identifier */
  uint32_t          dir_sig;
  image_dir_slot_t  slots[IMAGE_DIR_SLOTS];
  uint32_t          dir_sig_a;
  uint32_t          chksum;
} image_dir_t;


/*
 * ImageManager Events
 */
enum {
  IMGMGR_EV_NONE   = 0,
  IMGMGR_EV_ALLOC  = 1,
  IMGMGR_EV_ABORT  = 2,
  IMGMGR_EV_FINISH = 3,
  IMGMGR_EV_DELETE = 4,
  IMGMGR_EV_ACTIVE = 5,
  IMGMGR_EV_BACKUP = 6,
  IMGMGR_EV_EJECT  = 7,
};

#endif  /* __IMAGE_MGR_H__ */
