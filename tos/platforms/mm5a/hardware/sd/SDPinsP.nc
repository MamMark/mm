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

module SDPinsP {
  provides {
    interface SDInterface as HW;
  }
  uses {
    interface HplMsp430Usci as Usci;
  }
}
implementation {
MSP430REG_NORACE(P3SEL);
MSP430REG_NORACE(P5SEL);
MSP430REG_NORACE(P8DIR);

/*
 * The MM5a is clocked at 8MHz.
 *
 * There is documentation that says initilization on the SD
 * shouldn't be done any faster than 400 KHz to be compatible
 * with MMC which is open drain.  We don't have to be compatible
 * with that.  We've tested at 8MHz and everything seems to
 * work fine.
 *
 * Normal operation occurs at 8MHz.  The usci on the 2618 can be
 * run as fast as smclk which can be set to be the main dco frequency
 * which is at 8MHz.  Currently we run at 8MHz.   The SPI runs at
 * DCO/1 to maximize its performance.  Timers run at DCO/8 (max
 * divisor) to get 1uis ticks.  If we increase DCO to 16 MHz there
 * is a problem with the main timer because the max divisor is
 * /8.  This impacts timing for all the timers.
 *
 * MM5, 5438a, USCI, SPI, sc interface
 * phase 1, polarity 0, msb, 8 bit, master,
 * mode 3 pin, sync.
 *
 * UCCKPH: 1,         data captured on rising edge
 * UCCKPL: 0,         inactive state is low
 * UCMSB:  1,
 * UC7BIT: 0,         8 bit
 * UCMST:  1,
 * UCMODE: 0b00,      3 wire SPI
 * UCSYNC: 1
 * UCSSEL: SMCLK
 */

#define SPI_8MHZ_DIV    1
#define SPI_FULL_SPEED_DIV SPI_8MHZ_DIV

const msp430_usci_config_t sd_spi_config = {
  ctl0 : (UCCKPH | UCMSB | UCMST | UCSYNC),
  ctl1 : UCSSEL__SMCLK,
  br0  : SPI_8MHZ_DIV,		/* 8MHz -> 8 MHz */
  br1  : 0,
  mctl : 0,                     /* Always 0 in SPI mode */
  i2coa: 0
};


  async command void HW.sd_spi_init() {
    SD_PINS_INPUT;			// all data pins inputs
    call HW.sd_spi_disable();
    call HW.sd_off();
  }

  async command void HW.sd_spi_enable() {
    SD_PINS_SPI;			// switch pins over
    call Usci.configure(&sd_spi_config, FALSE);
  }

  async command void HW.sd_spi_disable() {
    SD_PINS_INPUT;			// all data pins inputs
    call Usci.enterResetMode_();        // just leave in reset
  }

  async command void HW.sd_access_enable()      { SD_ACCESS_ENA_N = 0; }
  async command void HW.sd_access_disable()     { SD_ACCESS_ENA_N = 1; }
  async command bool HW.sd_access_granted()     { return !SD_ACCESS_SENSE; }
  async command bool HW.sd_check_access_state() { return TRUE; }

  async command void HW.sd_on() {
    SD_CSN = 1;				// make sure tristated
    SD_ACCESS_ENA_N = 0;
    SD_PWR_ENA = 1;
  }

  /*
   * turn sd_off and switch pins back to port (1pI) so we don't power the
   * chip prior to powering it off.
   */
  async command void HW.sd_off() {
    SD_CSN = 1;				// tri-state by deselecting
    SD_ACCESS_ENA_N = 1;
    SD_PWR_ENA = 0;
  }

  async command bool HW.isSDPowered() { return (SD_PWR_ENA != 0); }

  async command void    HW.sd_set_cs()          { SD_CSN = 0; }
  async command void    HW.sd_clr_cs()          { SD_CSN = 1; }
}
