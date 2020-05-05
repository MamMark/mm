/*
 * Copyright (c) 2020, Eric B. Decker
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

/**
 * Define the interface to uBlox GPS chips using Port Abstractionish.
 *
 * Following pins can be manipulated:
 *
 *  gps_reset():        (set/clr) access to reset pin.
 *
 *  gps_powered():      return true if gps is powered (h/w power).
 *  gps_pwr_on():       turn pwr on (really?)
 *  gps_pwr_off():      your guess here.
 *
 *  gps_speed_di():     set speed on port, disable rx interrupt
 *  gps_tx_finnish():   make sure all transmit bytes have gone out.
 *  gps_rx_int_enable:  enable/disable rx interrupt.
 *  gps_rx_int_disable:
 *
 *  gps_rx_err:         report rx errors
 *  gps_clear_rx_errs:  clear rx_errs cells.
 *
 *
 * data transfer
 *
 *   gps_byte_avail():      from h/w driver to gps driver.
 *   gps_receive_dma():     continue receive into a particular
 *                          buffer with length
 *   gps_receive_dma_done() completion
 *
 *   gps_rx_off():          flow control, shut down gps transmission
 *   gps_rx_on():           flow control, turn gps transmission on
 *
 *   gps_send_block():      split phase.
 *   gps_send_block_done(): completion on split phase
 *   gps_send_block_stop(): stop current send_block (abort)
 *   gps_restart_tx():      restart tx
 *   gps_hw_capture():      capture USCI state (debug ONLY, destructive).
 *
 *   gps_receive_block():   same as send but for receive
 *   gps_receive_block_done():
 *   gps_receive_block_stop():
 *
 * @author Eric B. Decker <cire831@gmail.com>
 */

interface ubloxHardware {

  async command void gps_set_reset();
  async command void gps_clr_reset();

  async command bool gps_powered();
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

  /* rx_int_enable makes sure that any rx_errors have been cleared. */
  async command void gps_rx_int_enable();
  async command void gps_rx_int_disable();

  /*
   * h/w error handling.
   * gps_rx_err signals from the underlying h/w.
   *
   * raw_errors, raw from the h/w (untranslated) errors.
   * gps_errors, translated from the h/w into errors defined in gpsproto.h
   */
  async event   void gps_rx_err(uint16_t gps_errors, uint16_t raw_errors);
  async command void gps_clear_rx_errs();

  /*
   * Data transfer
   */

  async event   void    gps_byte_avail(uint8_t byte);
  async command void    gps_rx_on();
  async command void    gps_rx_off();

  async command error_t gps_send_block(uint8_t *ptr, uint16_t len);
  async command void    gps_send_block_stop();
  async event   void    gps_send_block_done(uint8_t *ptr, uint16_t len, error_t error);
  async command bool    gps_restart_tx();
  async command void    gps_hw_capture();

  async command error_t gps_receive_block(uint8_t *ptr, uint16_t len);
  async command void    gps_receive_block_stop();
  async event   void    gps_receive_block_done(uint8_t *ptr, uint16_t len, error_t err);
}
