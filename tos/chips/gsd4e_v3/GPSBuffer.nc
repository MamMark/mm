/*
 * Copyright (c) 2017 Eric B. Decker
 * All rights reserved.
 *
 * Redistribution and use in source and binary forms, with or without
 * modification, are permitted provided that the following conditions
 * are met:
 *
 * - Redistributions of source code must retain the above copyright
 *   notice, this list of conditions and the following disclaimer.
 *
 * - Redistributions in binary form must reproduce the above copyright
 *   notice, this list of conditions and the following disclaimer in the
 *   documentation and/or other materials provided with the
 *   distribution.
 *
 * - Neither the name of the copyright holders nor the names of
 *   its contributors may be used to endorse or promote products derived
 *   from this software without specific prior written permission.
 *
 * THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS
 * "AS IS" AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT
 * LIMITED TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS
 * FOR A PARTICULAR PURPOSE ARE DISCLAIMED.  IN NO EVENT SHALL
 * THE COPYRIGHT HOLDER OR CONTRIBUTORS BE LIABLE FOR ANY DIRECT,
 * INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES
 * (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR
 * SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION)
 * HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT,
 * STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE)
 * ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED
 * OF THE POSSIBILITY OF SUCH DAMAGE.
 */

#include <GPSMsgBuf.h>

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
   * returns:  ptr      to message data
   *                    NULL if no more messages.
   *
   * Will set the state of the head of the message queue to BUSY.
   */
  command uint8_t *msg_next();

  /*
   * msg_release: release a previously allocated msg.
   *
   * input: pointer to msg_data.
   *
   * the message needs to be the next one expected.  (strict
   * first-in-first-out).
   */
  command void msg_release(uint8_t *msg_data);

  /*
   * msg_available is signalled any time the message queue
   * goes from empty to something.
   */
  async event void msg_available();
}
