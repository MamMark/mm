/*
 * Copyright (c) 2017 Eric B. Decker
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
 * Definitions for the Dblk directory.
 *
 * The Dblk manager controls initialization of the data stream
 * subsystem.
 */

#ifndef __DBLK_DIR_H__
#define __DBLK_DIR_H__

#include <datetime.h>

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
  datetime_t incept_date;
  uint8_t    file_idx;                  /* file idx */
  uint8_t    pad;
  uint32_t   dblk_dir_sig_a;
  uint32_t   chksum;
} dblk_dir_t;

#endif  /* __DBLK_DIR_H__ */
