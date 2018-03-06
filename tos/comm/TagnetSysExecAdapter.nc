/**
 * @Copyright (c) 2017 Daniel J. Maltbie
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
 * @author Daniel J. Maltbie <dmaltbie@daloma.org>
 */

#include <TagnetTLV.h>
#include <image_info.h>

interface TagnetSysExecAdapter {
  /**
   * Get the version associated with this executive.
   *
   * @param   'image_ver_t         *verp' buffer to hold version
   * @return  'error_t'             TRUE  if value is valid
   */
   command error_t get_version(image_ver_t *verp);
  /**
   * Get the current state for this executive.
   *
   * @return  'uint8_t'             char letter of current state
   */
   command uint8_t get_state();
   /**
   * Set the version associated with this executive.
   *
   * @param   'image_ver_t         *verp' buffer to hold version
   * @return  'error_t'             TRUE  if value is valid
   */
   command error_t set_version(image_ver_t *verp);
}
