/**
 * SDsa - SD standalone (non-event) access
 *
 * Copyright (c) 2010, Eric B. Decker, Carl W. Davis
 * Copyright (c) 2017, Eric B. Decker
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
 *          Carl W. Davis
 */

interface SDsa {
  async command bool inSA();
  async command error_t reset();
  async command void off();
  async command void read(uint32_t blk_id, uint8_t *buf);
  async command void write(uint32_t blk, uint8_t *buf);
}
