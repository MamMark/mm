/*
 * Copyright (c) 2015-2016, Eric B. Decker
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
 * Define the interface to Gsd4e GPS chips.  Following pins can be
 * manipulated:
 *
 *  gps_on_off: access to interrupt pin.  Also needs to be wired into
 *  gps_csn:    low true chip select
 *  gps_reset:  access to clear to send mechanism.  Either via a gpio h/w
 *  gps_awake:  will be 1 if the chip is awake (turned on).
 *
 *  gps_spi_init: sets up spi and any initial power state
 *  gps_spi_enable: turn spi back on, come out of low power
 *  gps_spi_disable: turn spi off, go into low power mode.
 *
 *  SPI interface:
 *    gps_sclk
 *    gps_miso
 *    gps_mosi
 *
 * @author Eric B. Decker <cire831@gmail.com>
 */
 
interface Gsd4eInterface {

  async command void gps_spi_init();
  async command void gps_spi_enable();
  async command void gps_spi_disable();

  /**
   * gps_set_on_off: turn the on_off pin on.
   *
   * if the GPS is off, on_off needs to be toggled.
   *
   * supposedly, if the GPS is on we can turn it off by
   * also toggling on_off but we haven't seen that work.
   */
  async command void gps_set_on_off();


  /**
   * gps_clr_on_off: clear on_off pin (turn off).
   */
  async command void gps_clr_on_off();

  /**
   * gps_set_cs: assert chip select
   *
   * CSN = 0 (low true)
   */
  async command void gps_set_cs();

  /**
   * gps_clr_cs: unassert chip select
   */
  async command void gps_clr_cs();

  /**
   * gps_set_reset: assert RESET
   */
  async command void gps_set_reset();

  /**
   * gps_clr_reset: deassert RESET
   */
  async command void gps_clr_reset();

  /**
   * gps_awake: return awake status of gps.
   */
  async command bool gps_awake();

  /*
   * If there is seperate power control for the gps, these routines
   * control the power.
   */
  async command void gps_on();
  async command void gps_off();
}
