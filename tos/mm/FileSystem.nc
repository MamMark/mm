/**
 * Copyright (c) 2017, Eric B. Decker
 * Copyright (c) 2010, Eric Decker, Carl Davis
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

#include <fs_loc.h>

interface FileSystem {
  /*
   * return area start and end
   */
  async command uint32_t area_start(uint8_t which);
  async command uint32_t area_end(uint8_t which);

  /* erase a region, split phase */
  command error_t  erase(uint8_t which);
  event   void     eraseDone(uint8_t which);

  /*
   * standalone
   *
   * Force a reload of the locator block.
   * This is a standalone version used by Panic to ensure
   * that a good locator is loaded so it can find the
   * panic region.
   */
  async command error_t  reload_locator_sa(uint8_t *buf);
}
