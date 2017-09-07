/*
 * Copyright (c) 2017 Eric B. Decker, Miles Maltbie
 * All rights reserved.
 *
 * Redistribution and use in source and binary forms, with or without
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
  uint32_t          dir_sig;
  image_dir_slot_t  slots[IMAGE_DIR_SLOTS];
  uint32_t          dir_sig_a;
  uint32_t          chksum;
} image_dir_t;

#endif  /* __IMAGE_MGR_H__ */
