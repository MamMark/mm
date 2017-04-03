/*
 * Collect.h - data collector (record managment) interface
 * between data collection and mass storage.
 *
 * Copyright 2008, 2017 Eric B. Decker
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

#ifndef __COLLECT_H__
#define __COLLECT_H__

#include "stream_storage.h"

/*
 * DC_BLK_SIZE is 4 less then the block size of mass storage.  last 2 bytes
 * is a running checksum (sum the block to 0).  The two bytes before that
 * is a little endian order sequence number.  It is reset to zero on a
 * restart/reboot.
 *
 * Mass Storage block size is 512.  If this changes the tag is severly
 * bolloxed as this number is spread a number of different places.  Fucked
 * but true.
 *
 * Buffers obtained from StreamStorage are 514 bytes long and include space
 * for the CRC that the SD format provides for.  Data transfered to/from
 * the SD need this space.
 *
 *   0   ---   Data   508 bytes
 *   508 ---   2 byte le seq number
 *   510 ---   2 byte le checksum
 *
 * The current implementation will put whole typed_data blocks (dblks) into
 * a sector.  In other words, dblks will not be split across sectors, the
 * whole thing has to fit.
 *
 * If a dblk does not fit, a DT_TINTRYALF record will be laid down which
 * tells the system to go to the next block.  Since we always keep dblks
 * aligned to 32 bits even in the sector buffer we have either perfectly
 * fit or we have at least one 32 bit area left.  The DT_TINTRYALF dblk is
 * exactly 32 bits long, 2 byte len (value 4) and 2 byte dtype
 * DT_TINTRYALF.
 *
 * The rationale for only putting whole dblk records into a sector is to
 * optimize access.  Both writing and reading.  The Tag is a highly
 * constrained, very limited resource computing system.  As such we want to
 * make both writing as well as reading to be reasonably efficient and that
 * mean minimizing special cases, like when we run off the end of a sector.
 *
 * By organizing how dblk records layout in memory and how they lay out on
 * disk sectors, we should be able to minimize how much additonal overhead
 * is caused by misalignment problems as well as minimize special cases.
 *
 * That's the design philosophy anyway.
 */

#define DC_BLK_SIZE   508
#define DC_SEQ_LOC    508
#define DC_CHKSUM_LOC 510

typedef struct {
  uint16_t majik_a;
  ss_wr_buf_t *handle;
  uint8_t *cur_buf;
  uint8_t *cur_ptr;
  uint16_t remaining;
  uint16_t chksum;
  uint16_t seq;
  uint16_t majik_b;
} dc_control_t;

#define DC_MAJIK 0x1008

#endif  /* __COLLECT_H__ */
