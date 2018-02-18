/**
 * Copyright (c) 2008, 2010, 2017-2018 Eric Decker
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
   * get_dblk_low(): get the base blk_id of the Dblk Area.
   *
   * return absolute blk_id of the start of the DBLK file
   */
  command uint32_t get_dblk_low();


  /**
   * get_dblk_high(): get the upper inclusive limit of the Dblk Area.
   *
   * return absolute blk_id of the end (inclusive) of the DBLK file
   */
  command uint32_t get_dblk_high();


  /**
   * eof_offset():       return the offset of the eof.
   * committed_offset(): return the offset of last committed data.
   *
   * the block offset is the file offset of tne next block being written
   * or that will be written.  dblk_nxt + number of full buffers converted
   * to a file offset.  Block offsets are always modulo SD_BLOCKSIZE.
   *
   * committed_offset() will return the offset of all data that has been
   * physically written to disk.
   *
   * can be called from anywhere.
   */
  async command uint32_t eof_offset();
  async command uint32_t committed_offset();


  /**
   * where(): determine where a given offset in the Dblk stream lives.
   *
   * @param   'uint32_t context'
   * @param   'uint32_t offset'       offset to find
   * @param   'uint32_t *lenp'        pointer to returned length
   * @param   'uint32_t *blk_offsetp' pointer to returned blk offset
   * @param   'uint8_t **bufp'        pointer to returned buffer
   *
   * @return: 'uint32_t blk_id'       absolute blk_id of found offset.
   */
  command uint32_t where(uint32_t context, uint32_t offset, uint32_t *lenp,
                         uint32_t *blk_offsetp, uint8_t **bufp);


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
