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
 * Primary user interface for accessing the Tagnet protocol stack.
 *<p>
 * The Tagnet Stack provides the handling of Tagnet request messages. This
 * includes the following steps:
 *</p>
 *<ul>
 * <li>Match the request message name with one of the names instantiated in the stack.</li>
 * <li>If matched, then process the message action to access the named data object.</li>
 * <li>Optionally format a response message using the same buffer as the request.</li>
 *</ul>
 */

#include "message.h"

interface Tagnet {
  /**
   * Process the Tagnet request message and return flag if response message needs
   * to be transmitted.
   *
   * @param   msg    pointer to message buffer containing Tagnet Request packet
   * @return         TRUE if response should be sent (in same buffer as original request)
   */
  command bool  process_message(message_t *msg);
}
