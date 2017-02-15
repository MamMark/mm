/*
 * Copyright (c) 2016-2017, Eric B. Decker
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
  async command void sd_stop_dma();

  async command void sd_dma_enable_int();
  async command void sd_dma_disable_int();
  async event   void sd_dma_interrupt();
}
