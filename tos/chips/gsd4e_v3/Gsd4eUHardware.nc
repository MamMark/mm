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
 *  gps_on_off():       (set/clr) acces  s to on_off pin.
 *  gps_reset():        (set/clr) access to reset pin.
 *  gps_awake():        will be 1 if the chip is awake (turned on, full power).
 *  gps_pwr_on():       turn pwr on (really?)
 *  gps_pwr_off():      your guess here.
 *
 *  gps_tx_finnish():   make sure all transmit bytes have gone out.
 *  gps_speed_di():     set speed on port, disable rx interrupt
 *
 *  gps_port_interrupt_disable():
 *  gps_port_interrupt_enable():
 *
 *
 * data transfer
 *
 *   byte_avail():      from h/w driver to gps driver.
 *   receive_dma():     continue receive into a particular
 *                      buffer with length
 *   receive_dma_done() completion
 *   gps_rx_off():      flow control, shut down gps transmission
 *   gps_rx_on():       flow control, turn gps transmission on
 *
 *   send_block():      split phase.
 *   send_done():       completion on split phase
 *
 * This interface has been optimized for high-speed, where high-speed is
 * assumed to be something like 122880 Bbps (~8uS/byte).  On receive, the
 * driver hands the incoming byte to the upper layer where simple
 * processing is performed, on return it is probable that another byte will
 * have arrived.  This continues until there is a gap in the incoming
 * stream.  If flow control is implemented, this can be used to force a
 * gap.
 *
 * The upper level needs to be able to deal with a burst of packets and we
 * will tune the buffering to accommodate the typical conditions.  The hw
 * driver doesn't worry about it but is kept purposedly simple to minimize
 * instructions.
 *
 * Sending is similar.  If we are in high-speed mode then bytes will be
 * egressing at ~8us/byte.  Doesn't make sense to run this off interrupts,
 * hence the run to completion.  Run to completion transmission is started
 * using send_immediate().
 *
 * Alternatively, the hw driver can use dma to run the transmission, it
 * knows what the fixed size of the message it so this meshes well.  A dma
 * based split phase transmission is started using send_block() and completes
 * with the signal send_done();
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

  async command void gps_tx_finnish();
  async command void gps_rx_int_enable();
  async command void gps_rx_int_disable();

  /*
   * Data transfer
   */

  async event   void    byte_avail(uint8_t byte);
  async command error_t receive_block(uint8_t *ptr, uint16_t len);
  async command void    receive_abort();
  async event   void    receive_done(uint8_t *ptr, uint16_t len, error_t err);
  async command void    gps_rx_off();
  async command void    gps_rx_on();

  async command error_t send_block(uint8_t *ptr, uint16_t len);
  async command void    send_abort();
  async event   void    send_done(uint8_t *ptr, uint16_t len, error_t error);
}
