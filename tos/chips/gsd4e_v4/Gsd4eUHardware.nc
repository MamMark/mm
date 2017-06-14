/*
 * Copyright (c) 2017, Eric B. Decker, Dan Maltbie
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

/**
 * Define the interface to Gsd4e GPS chips using the Port Abstractionish.
 *
 * Following pins can be manipulated:
 *
 *  gps_on_off():       (set/clr) access to on_off pin.
 *  gps_reset():        (set/clr) access to reset pin.
 *  gps_awake():        will be 1 if the chip is awake (turned on, full power).
 *
 *  gps_pwr_on():       turn pwr on (really?)
 *  gps_pwr_off():      your guess here.
 *
 *  gps_speed_di():     set speed on port, disable rx interrupt
 *  gps_tx_finnish():   make sure all transmit bytes have gone out.
 *  gps_rx_int_enable:  enable/disable rx interrupt.
 *  gps_rx_int_disable:
 *
 *
 * data transfer
 *
 *   gps_byte_avail():      from h/w driver to gps driver.
 *   gps_receive_dma():     continue receive into a particular
 *                          buffer with length
 *   gps_receive_dma_done() completion
 *   gps_rx_off():          flow control, shut down gps transmission
 *   gps_rx_on():           flow control, turn gps transmission on
 *
 *   gps_send_block():      split phase.
 *   gps_send_block_done(): completion on split phase
 *   gps_send_block_stop(): stop current send_block (abort)
 *
 *   gps_receive_block():   same as send but for receive
 *   gps_receive_block_done():
 *   gps_receive_block_stop():
 *
 *   gps_rx_on():
 *   gps_rx_off():
 *
 * This interface has been optimized for high-speed, where high-speed is
 * assumed to be something like 1228800 bps (~8uS/byte).  On receive, the
 * driver hands the incoming byte to the upper layer where simple
 * processing is performed, on return it is probable that another byte will
 * have arrived.  This continues until there is a gap in the incoming
 * stream.  If flow control is implemented, this can be used to force a
 * gap.
 *
 * We however, run the gps in UART mode at 115200.  The problem is interbyte
 * times.  At 1228800, the interbyte time is ~8us.  Which effectively means
 * when receiving a gps packet the processor is doing nothing else.  Further
 * the overhead of the interrupt exacerbates the cost of doing each byte.
 * This gets worse given that the gps can spit out multiple packets back to
 * back.
 *
 * Things are more balanced at 115200 bps which has an interbyte time of
 * ~87us.  Which gives the cpu time to get other work done.  This includes
 * being able to process in some fashion the incoming packets.
 *
 * The upper level needs to be able to deal with a burst of packets and we
 * will tune the buffering to accommodate the typical conditions.  The hw
 * driver doesn't worry about it but is kept purposedly simple to minimize
 * instructions.
 *
 * Sending is similar.  If we are in high-speed mode then bytes will be
 * egressing at ~8us/byte.  Doesn't make sense to run this off interrupts,
 * hence the run to completion.  Run to completion transmission is started
 * using send_immediate().  However, at low speeds this is very dangerous
 * because the run to completion locks others out and take too long.  Gag.
 * So it has been removed.
 *
 * Running at 115200 the sending occurs at 1 byte every ~87us which also
 * gives the processor time to process other things that need to be done.
 *
 * Alternatively, the hw driver can use dma to run the transmission, it
 * knows what the fixed size of the message it so this meshes well.  A dma
 * based split phase transmission is started using send_block() and
 * completes with the signal gps_send_block_done(); A block transmission
 * can be aborted using gps_send_block_stop();
 *
 * We run at 115200.  Its a good choice.  The downside is potentially
 * we may have to keep the gps up longer while communicating.  The
 * intent though is to run the gps using Micro Power Mode (MPM) where
 * the GPS controls when it is running and when it is sleeping.  How
 * long we stay up for communications becomes somewhat moot because
 * we do not control power so have no say in the decision.
 *
 * @author Eric B. Decker <cire831@gmail.com>
 * @author Daniel J. Maltbie <dmaltbie@daloma.org>
 */

interface Gsd4eUHardware {

  async command void gps_set_on_off();
  async command void gps_clr_on_off();
  async command void gps_set_reset();
  async command void gps_clr_reset();
  async command bool gps_awake();

  async command void gps_pwr_on();
  async command void gps_pwr_off();

  /*
   * gps_speed_di reconfigures the usci which turns off interrupts
   *
   * _di on the end indicates that this also disables interrupts.
   * this is a side effect of reconfiguring.
   */
  async command void gps_speed_di(uint32_t speed);

  async command void gps_tx_finnish(uint32_t byte_delay);
  async command void gps_rx_int_enable();
  async command void gps_rx_int_disable();

  /*
   * Data transfer
   */

  async event   void    gps_byte_avail(uint8_t byte);
  async command error_t gps_receive_block(uint8_t *ptr, uint16_t len);
  async command void    gps_receive_block_stop();
  async event   void    gps_receive_block_done(uint8_t *ptr, uint16_t len, error_t err);
  async command void    gps_rx_on();
  async command void    gps_rx_off();

  async command error_t gps_send_block(uint8_t *ptr, uint16_t len);
  async command void    gps_send_block_stop();
  async event   void    gps_send_block_done(uint8_t *ptr, uint16_t len, error_t error);
}
