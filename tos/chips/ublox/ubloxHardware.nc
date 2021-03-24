/*
 * Copyright (c) 2020-2021, Eric B. Decker
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
 *  gps_csn():            (set/clr) chip select.
 *  gps_reset_pin():      (set/clr) access to reset pin.
 *  gps_sw_reset():       s/w reset message
 *
 *  gps_powered():        return true if gps is powered (h/w power).
 *  gps_pwr_on():         turn pwr on (really?)
 *  gps_pwr_off():        your guess here.
 *
 * data transfer
 *
 *  spi_clr_port():       put spi port into pristine state.
 *  spi_put():            splitWrite()     w timeout
 *  spi_get():            splitRead()      w timeout
 *  spi_getput():         splitReadWrite() w timeout
 *
 *  spi_pipe_stall():     signal indicating that the spi pipe has stalled.
 *  spi_pipe_restart():   restart spi pipeline.
 *
 *  gps_txrdy():             returns state of txrdy pin
 *  gps_txrdy_int_enabled(): returns state of txrdy interrupt
 *  gps_txrdy_int_enable():  enable/disable txrdy interrupt.
 *  gps_txrdy_int_disable():
 *
 *  gps_send_block():     transmit a block of data.
 *  gps_send_block_done():
 *  gps_byte_avail():     from h/w layer to chip driver.
 *
 *  gps_raw_collect():    request collection of a gps raw packet
 *
 * @author Eric B. Decker <cire831@gmail.com>
 */

interface ubloxHardware {

  command void gps_set_cs();
  command void gps_clr_cs();
  command void gps_clr_cs_delay();

  command void gps_set_reset();
  command void gps_clr_reset();
  command void gps_sw_reset(uint16_t bbr_mask, uint8_t reset_mode);

  command bool gps_powered();
  command void gps_pwr_on();
  command void gps_pwr_off();

  command void    spi_clr_port();
  command void    spi_put(uint8_t byte);
  command uint8_t spi_get();
  command uint8_t spi_getput(uint8_t byte);


  event   void    spi_pipe_stall();
  command void    spi_pipe_restart();

  command bool gps_txrdy();
  command bool gps_txrdy_int_enabled();
  command void gps_txrdy_int_enable(uint32_t where);
  command void gps_txrdy_int_disable();
  command void gps_txrdy_int_clear();

  /*
   * Data transfer
   */
  command void gps_send(uint8_t *ptr, uint16_t len);
  event   void gps_send_done(error_t err);
  event   void gps_byte_avail(uint8_t byte);

  event   void gps_raw_collect(uint8_t *pak, uint16_t len, uint8_t dir);
}
