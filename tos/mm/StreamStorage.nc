/**
 * Copyright (c) 2008, 2010, 2017 Eric Decker
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

interface StreamStorage {
  /**
   * return absolute blk_id of the start of the DBLK file
   */
  command uint32_t get_dblk_low();

  /**
   * eof_block_offset(): return the offset of the block containing the eof.
   *
   * the block offset is the file offset of tne next block being written
   * or that will be written.  dblk_nxt + number of full buffers converted
   * to a file offset.  Block offsets are always modulo SD_BLOCKSIZE.
   *
   * can be called from anywhere.
   */
  async command uint32_t eof_block_offset();


  /**
   * The event "dblk_stream_full" is signaled when the assigned area
   * for data block storage is full.  Typically this will cause the
   * sensing system to shut down and put the tag into a low power
   * try to connect to the world mode.
   */
  event void dblk_stream_full();

  /**
   * The event dblk_advanced tells folks that a new dblk sector has
   * been written out to the SD.
   *
   * The parameter is last dblk blk_id that was written.
   */
  event void dblk_advanced(uint32_t last);
}
