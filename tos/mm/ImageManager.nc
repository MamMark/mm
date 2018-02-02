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

interface ImageManager {
  command error_t alloc(image_ver_t *ver_id);
  command error_t alloc_abort();

  command uint32_t write(uint8_t *buf, uint32_t len);
  event   void     write_continue();

  command error_t finish();
  event   void    finish_complete();

  command error_t delete(image_ver_t *ver_id);
  event   void    delete_complete();

  command error_t dir_set_active(image_ver_t *ver_id);
  event   void    dir_set_active_complete();

  command error_t dir_set_backup(image_ver_t *ver_id);
  event   void    dir_set_backup_complete();

  command error_t dir_eject_active();
  event   void    dir_eject_active_complete();
}
