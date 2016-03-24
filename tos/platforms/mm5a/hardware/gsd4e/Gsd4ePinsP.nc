/*
 * Copyright (c) 2016 Eric B. Decker
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
 * @author Eric B. Decker <cire831@gmail.com>
 */

#include "mmPortRegs.h"
#include "msp430usci.h"

module Gsd4ePinsP {
  provides interface Gsd4eInterface as HW;
  uses interface     HplMsp430Usci  as Usci;
}
implementation {
/*
 * The Gsd4e (M10478) module is always powered on, it puts itself to sleep
 * so we don't have to deal with that.  We set up the i/o pins appropriately
 * on boot up (see hardware/pins/PlatformPins) and then leave them alone.  No
 * need to switch to inputs to avoid powering the chip etc.
 *
 * The MM5a is clocked at 8MHz.
 *
 * MM5, 5438a, USCI, SPI, gps interface
 * phase 0, polarity 0, msb, 8 bit, master,
 * mode 3 pin, sync.
 *
 * UCCKPH: 0,           data captured on falling edge
 * UCCKPL: 0,           inactive state is low
 * UCMSB:  1,
 * UC7BIT: 0,
 * UCMST:  1,
 * UCMODE: 0b00,        3 wire SPI
 * UCSYNC: 1,
 * UCSSEL: SMCLK,
 */

  const msp430_usci_config_t gps_spi_config = {
    ctl0 : (UCMSB | UCMST | UCSYNC),
    ctl1 : UCSSEL__SMCLK,
    br0  : 2,                           /* 8MHz -> 4 MHz */
    br1  : 0,
    mctl : 0,                           /* Always 0 in SPI mode */
    i2coa: 0
  };

  async command void HW.gps_spi_init() {
    call Usci.configure(&gps_spi_config, FALSE);
  }

  async command void HW.gps_spi_enable()  { }
  async command void HW.gps_spi_disable() { }

  async command void HW.gps_set_on_off() { GSD4E_GPS_SET_ONOFF; }
  async command void HW.gps_clr_on_off() { GSD4E_GPS_CLR_ONOFF; }
  async command void HW.gps_set_cs()     { GSD4E_GPS_CSN = 0; }
  async command void HW.gps_clr_cs()     { GSD4E_GPS_CSN = 1; }
  async command void HW.gps_set_reset()  { GSD4E_GPS_RESET; }
  async command void HW.gps_clr_reset()  { GSD4E_GPS_UNRESET; }
  async command bool HW.gps_awake()      { return GSD4E_GPS_AWAKE; }
}
