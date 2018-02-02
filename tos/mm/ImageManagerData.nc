/*
 * Copyright (c) 2017 Eric B. Decker, Miles Maltbie
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
 *          Miles Maltbie <milesmaltbie@gmail.com>
 */

#include <image_mgr.h>

interface ImageManagerData {
  command bool    check_fit(uint32_t len);
  command bool    verEqual(image_ver_t *ver0, image_ver_t *ver1);
  command void    setVer(image_ver_t *src, image_ver_t *dst);
  command uint8_t slotStateLetter(slot_state_t state);

  command image_dir_slot_t *dir_get_active();
  command image_dir_slot_t *dir_get_backup();
  command image_dir_slot_t *dir_get_dir(uint8_t idx);
  command image_dir_slot_t *dir_find_ver(image_ver_t *ver_id);

  command bool dir_coherent();
}
