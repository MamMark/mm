/*
 * Copyright (c) 2017 Eric B. Decker
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

/*
 * GPSReceive.msg_available
 *
 * signals to a receiver that a new message is available from the GPS
 * subsystem.
 *
 * output to the signal handler:
 *
 *   msg:        pointer to the raw gps message.
 *   len:        length of said message.
 *   dtp:        datetime ptr to the arrival time of the message.
 *   mark_j:     time mark stamp if any in system jiffies
 *
 * The message format will be specified by whatever protocol is
 * currently being used by the GPS chip.  Typically SirfBin.
 *
 * The message lives for the duration of the signal call out and upon return
 * the message will be consumed by the GPS sublayer.
 */

#include <datetime.h>

interface GPSReceive {
  /*
   * msg_available
   *
   * will be signaled when a new message is available for processing.
   */
  event   void     msg_available(uint8_t *msg, uint16_t len,
                                 datetime_t *dtp, uint32_t mark_j);
}
