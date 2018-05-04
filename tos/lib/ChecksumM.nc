/*
 * Copyright (c) 2017-2018 Eric B. Decker
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
 * __checksum32_aligned: 32 bit checksum, aligned buffer
 *
 * perform a 32 bit wide Little endian checksum.  Yields a 32 bit result.
 *
 * Accesses are done 32 bits wide.  Since little endian, the fetch will
 * reverse the byte order from a strict byte access ordering.
 *
 * Buffer is required to be aligned to a 4 byte (32 bit) alignment.  If not
 * will return 0.
 *
 * Additional references will be fetched and byte swapped (ie. addr 4 will
 * give us 7-6-5-4) and added to the sum.
 *
 * There may be some left over remanents.  Let's say we are at address
 * 0x100 with 2 bytes remaining.  We fetch 0x100, 103-102-101-100.  But we
 * only want 101 and 100 to be included in the sum.  So we AND the result
 * with 0x0000FFFF.
 *
 * This routine is written for 32 bit processors that have a memory system
 * optimized for 32 bit accesses.
 *
 * Initial alignment is forced to be aligned because dealing with startup
 * unaligned conditions is a royal pain and isn't needed in most cases.
 * Further, changing how the buffer is aligned will change the resultant
 * checksum which isn't good.
 *
 * To avoid these problems we insist on the buffer being aligned.
 */

uint32_t __checksum8(uint8_t *buf, uint32_t len) {
  uint32_t  sum;

  if (!len)
    return 0;

  sum = 0;
  while(len) {
    sum += *buf++;
    len--;
  }
  return sum;
}


uint32_t __checksum32_aligned(uint8_t *buf, uint32_t len) {
  uint32_t  sum;
  uint32_t *ptr;
  uint32_t  last;
  uint32_t  mask;

  if ((uintptr_t) buf & 3) {
    ROM_DEBUG_BREAK(0);
    return 0;
  }

  if (!len || ((uintptr_t) buf) & 3)
    return 0;

  sum = 0;
  ptr = (void *) buf;

  while (len > 32) {
    sum += *ptr++;                      /* 4 */
    sum += *ptr++;                      /* 8 */
    sum += *ptr++;                      /* 12 */
    sum += *ptr++;                      /* 16 */
    sum += *ptr++;                      /* 20 */
    sum += *ptr++;                      /* 24 */
    sum += *ptr++;                      /* 28 */
    sum += *ptr++;                      /* 32 */
    len -= 32;
  }
  while (len > 3) {
    sum += *ptr++;
    len -= 4;
  }
  if (len) {
    /*
     * ptr points at the long word that holds the remnant
     * ptr will still be aligned.
     *
     * 103-102-101-100: 0x000000FF 0x0000FFFF 0x00FFFFFF
     * remaining len             1       2        3
     */
    last = *ptr;
    mask = 0xffffffff >> ((4-len) * 8);
    sum += (last & mask);
  }
  return sum;
}


module ChecksumM {
  provides interface Checksum;
}
implementation {
  async command uint32_t Checksum.sum8(uint8_t *buf, uint32_t len) {
    return __checksum8(buf, len);
  }

  async command uint32_t Checksum.sum32_aligned(uint8_t *buf, uint32_t len) {
    return __checksum32_aligned(buf, len);
  }
}
