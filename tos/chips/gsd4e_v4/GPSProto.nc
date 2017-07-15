/*
 * Copyright (c) 2017, Eric B. Decker
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
 *
 * @author Eric B. Decker <cire831@gmail.com>
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
   * msgStart: signal that a new message has started.
   *
   * intent is to allow deadman timing to detect hung receivers
   */
  async event void msgStart(uint16_t len);

  /*
   * msgAbort: signal that the current receive has been aborted
   *
   * turn off any underlying timeout
   */
  async event void msgAbort(uint16_t reason);

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
