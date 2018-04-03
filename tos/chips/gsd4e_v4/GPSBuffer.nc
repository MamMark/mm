/*
 * Copyright (c) 2017-2018 Eric B. Decker
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

#include <GPSMsgBuf.h>
#include <rtctime.h>

interface GPSBuffer {

  /*
   * msg_start: start to collect a new message
   *
   * input:  len        size needed for the buffer.
   * output: uint8_t *  pointer to allocated space
   *
   * GPSBuffer will attempt to allocate len byte from the free space.
   * If enough space isn't available, GPSBuffer will go into GBCS_FLUSHING
   * and will drop the incoming message.
   *
   * DO NOT write past ptr+len.
   */
  async command uint8_t *msg_start(uint16_t len);

  /*
   * msg_abort: abort the currently msg and allocation
   *
   * return allocated space to the free pool
   */
  async command void msg_abort();

  /*
   * msg_complete: mark current message as complete and add to
   * end of msg queue.
   */
  async command void msg_complete();

  /*
   * msg_next: advance the message queue.
   *
   * input:    ptr/len  pointer to uint16_t that will receive the
   *                    length of the message.
   *           arrival/mark timestamps describing when the message arrived
   *                    pointer to a rtctime_t ptr and pointer to uint32_t.
   *
   * returns:  ptr      to message data
   *                    NULL if no more messages.
   *                    len filled in with length
   *                    *dtpp filled in with the ptr to the rtctime stamp
   *                    *markp filled in the mark value.
   *
   * Will set the state of the head of the message queue to BUSY.
   */
  command uint8_t *msg_next(uint16_t *len, rtctime_t **rtpp, uint32_t *markp);

  /*
   * msg_release: release a previously allocated msg.
   *
   * the message needs to be the next one expected.  (strict
   * first-in-first-out).  Assumed to be HEAD.
   */
  command void msg_release();
}
