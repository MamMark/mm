/*
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
 */

interface GPSProto {
  /*
   * rx_timeout: an rx_timeout has occurred.
   */
        command void rx_timeout();

  /*
   * rx_error: an rx_error has occurred.
   */
  async command void rx_error();

  /*
   * byteAvail: a new byte is available
   *
   * the underlying hw has a new byte that is being handed to the
   * protocol module.
   */
  async command void byteAvail(uint8_t byte);

  /*
   * protoAbort: signal that there has been a problem any where in the
   * packet.
   *
   * turn off any underlying timeout
   */
  async event void protoAbort(uint16_t reason);

  /*
   * msgStart: signal that a new message has started.
   *
   * intent is to allow deadman timing to detect hung receivers
   */
  async event void msgStart(uint16_t len);

  /*
   * msgEnd: signal the current message is complete
   *
   * turn off underlying deadman timer
   */
  async event void msgEnd();

  /*
   * msgBoundary and atMsgBoundary currently are not used.
   *
   * Potential deprecation
   */
#ifdef notdef
  async event   void msgBoundary();
  async command bool atMsgBoundary();
#endif
}
