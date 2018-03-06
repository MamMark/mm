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

/**
 *<p>
 * This is a generic interface used by the Tagnet stack to access
 * native C data types.  All of the network specific details are handled
 * by the stack, including conversion from a Native C format to the
 * network internal compact tlv format. The types of adapters supported
 *  is defined by the Tagnet TLV types.
 *</p>
 */

#include <Tagnet.h>

interface TagnetAdapter<tagnet_adapter_type> {
  /**
   * Get the value of the Tagnet named data object. The interface is
   * parameterized by the type of value that can be accessed. Examples
   * are integer, string, utc_time.
   *
   * @param   'tagnet_adapter_type *t'   pointer to an instance of adapter type
   * @param   'uint32_t            *len' pointer to length available/used
   * @return  'bool'                     TRUE if value is valid
   */
  command bool get_value(tagnet_adapter_type *t, uint32_t *len);
  /**
   * Set the value of the Tagnet named data object. The interface is
   * parameterized by the type of value that can be accessed. Examples
   * are integer, string, utc_time.
   *
   * @param   'tagnet_adapter_type *t'   pointer to an instance of adapter type
   * @param   'uint32_t            *len' pointer to length available/used
   * @return  'bool'                     TRUE if value is valid
   */
  command bool set_value(tagnet_adapter_type *t, uint32_t *len);
}
