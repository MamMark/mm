/*
 * Copyright (c) 2010, Eric B. Decker, Carl Davis
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
 *          Carl Davis
 */

interface SDread {
  /**
   * SD read, split phase.
   *
   * @input	blk_id:  which block to read
   *		buf:	 where to put the data, must SD_BLOCKSIZE (512).
   *
   * @return
   *   <li>SUCCESS if the request was accepted,
   *   <li>EINVAL  if the parameters are invalid
   *   <li>EBUSY if a request is already being processed.
   *
   * if SUCCESS, it is guaranteed that a future readDone will be signalled.
   */
  command error_t read(uint32_t blk_id, uint8_t *buf);
  event void  readDone(uint32_t blk_id, uint8_t *buf, error_t error);
}
