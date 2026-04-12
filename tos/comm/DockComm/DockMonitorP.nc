/**
 * Copyright (c) 2020 Eric B. Decker
 * All rights reserved
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

module DockMonitorP {
  uses {
    interface  MsgTransmit;
    interface MsgReceive;
  }
}
implementation {
  event void MsgReceive.msg_available(uint8_t *msg, uint16_t len,
        rtctime_t *arrival_rtp, uint32_t mark_j) {
    nop();
    call MsgTransmit.send(msg, len);
  }

  event void MsgTransmit.send_done(error_t err) { }
}
