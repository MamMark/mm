/*
 * Copyright (c) 2016-2017, Eric B. Decker
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
 *
 * lp = local processor
 */

/**
 * Defines the interface to a generic uSD card using SPI.
 *
 * Extra curricula: (beyond the scope of the driver itself).  But when
 * turning the SD on/off, these get manipulated.  Also we assume we have
 * a dedicated spi bus and the routines sd_spi_{en,dis}able are used
 * to turn that bus on and off as needed.
 *
 * When the SD is powered down, we need to make sure that no pins wired
 * to the SD are driven high as this can cause the card to power up via
 * those pins (because of the input clamping diodes).
 *
 *  sd_spi_enable:      configure the SPI for use.
 *  sd_spi_disable:     unconfigure the SPI for when the SD is powered down.
 *  sd_access_enable:   sd_access_{en,dis}able are called when the lp
 *  sd_access_disable:  wants to access (or not access) the uSD.
 *                      sd_access_granted is checked to see if the lp
 *                      actually has access.
 *  sd_access_granted:  If sd_access_enable has been called (and is currently
 *                      active), sd_access_granted will return true if the lp
 *                      currently has access to the uSD.
 *
 *  sd_check_access_state: called to check for proper access.  Pwr, etc.
 *
 *  sd_on:      turn SD on or off.
 *  sd_off
 *  isSDPowered: returns true if SD is powered on.
 *
 *  sd_csn: Chip select.  Must be pulled low via sd_set_cs() and
 *      cleared via sd_clr_cs().
 *
 *
 *  sd_set_cs:  set or clr chip select.
 *  sd_clr_cs
 *
 *  SPI interface:
 *    sd_sclk           h/w interface, particular port
 *    sd_miso
 *    sd_mosi
 *
 *    spi_check_clean
 *    spi_put
 *    spi_get
 *
 * @author Eric B. Decker <cire831@gmail.com>
 */

interface SDHardware {
  /*
   * SPI interface
   *
   * void spi_check_clean()
   *    check spi hardware for assumed start condition for idle spi bus
   *    panics if any checks fail.
   *
   * uint8_t spi_put(uint8_t byte)
   *    output byte, return returned byte.
   *
   * uint8_t spi_get()
   *    send dummy byte on spi, return returned byte.
   */

  async command void    spi_check_clean();
  async command uint8_t spi_put(uint8_t tx_byte);
  async command uint8_t spi_get();

  async command void sd_spi_enable();
  async command void sd_spi_disable();

  async command void sd_access_enable();
  async command void sd_access_disable();
  async command bool sd_access_granted();
  async command bool sd_check_access_state();

  async command void sd_on();
  async command void sd_off();
  async command bool isSDPowered();

  /**
   * sd_set_cs: manipulate chip select
   * sd_clr_cs
   **/
  async command void sd_set_cs();
  async command void sd_clr_cs();

  /*
   * dma interface
   */
  async command void sd_start_dma(uint8_t *sndptr, uint8_t *rcvptr, uint16_t length);
  async command void sd_wait_dma(uint16_t length);
  async command bool sd_dma_active();
  async command bool sd_stop_dma();

  async command void sd_dma_enable_int();
  async command void sd_dma_disable_int();
  async event   void sd_dma_interrupt();
}
