/*
 * Copyright (c) 2017, 2020, Eric B. Decker
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

#include <gpsproto.h>

interface GPSProto {
  /*
   * rx_timeout: an rx_timeout has occurred.
   */
        command void rx_timeout();

  /*
   * rx_error: an rx_error has occurred.
   * errors should be specified using definitions in gpsproto.h
   */
  command void rx_error(uint16_t errors);

  /*
   * restart: abort any pending packet in progress and restart.
   */
  command void restart();

  /*
   * resetStats
   * Stats are collected for a section of time, reported, and
   * cleared.
   *
   * logStats
   * tell the module to log the currently collected stats and
   * it will then clear the stats.
   */
  command void resetStats();
  command void logStats();

  /*
   * byteAvail: a new byte is available
   *
   * input:  byte       the byte (duh)
   * return: TRUE       at end of message.
   *         FALSE      otherwise
   *
   * the underlying hw has a new byte that is being handed to the
   * protocol module.
   */
  command bool byteAvail(uint8_t byte);

  /*
   * fletcher8: calculate fletcher8 checksum over buffer
   *
   * input:  ptr        ptr to buffer to checksum
   *         len        length of said buffer
   * output: return     (uint16_t)  (chk_a << 8) | chk_b
   */
  command uint16_t fletcher8(uint8_t *ptr, uint16_t len);


  /*
   * nema_sum: calculate the nema checksum over a buffer
   *
   * input:  ptr        ptr to buffer to checksum
   *         len        length of said buffer
   * output: return     checksum result (binary, one byte)
   */
  command uint8_t nema_sum(uint8_t *ptr, uint16_t len);


  /*
   * protoAbort: signal that there has been a problem any where in the
   * packet.
   *
   * turn off any underlying timeout
   */
  event void protoAbort(uint16_t reason);

  /*
   * msgStart: signal that a new message has started.
   *
   * intent is to allow deadman timing to detect hung receivers
   */
  event void msgStart(uint16_t len);

  /*
   * msgEnd: signal the current message is complete
   *
   * turn off underlying deadman timer
   */
  event void msgEnd();
}
