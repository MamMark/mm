/*
 * Copyright (c) 2018 Eric B. Decker
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

interface PlatformNodeId {
  /**
   * Platform dependent node id.
   *
   * Get a Platform defined node id.  This can typically be a serial number
   * or mac address.
   *
   * Platform define PLATFORM_SERIAL_NUM_SIZE determines the
   * size.  If not defined defaults to 4 bytes (uint32_t).
   *
   * input:  *lenp      pointer where to place the length of the number.
   *
   * output: *lenp      length filled in if non-null.
   * return: *uint8_t   pointer to the serial_num or NULL.
   */
  async command uint8_t *node_id(unsigned int *lenp);
}

