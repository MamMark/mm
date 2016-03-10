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

#include "mm4PortRegs.h"

module SDPinsP {
  provides {
    interface SDInterface as HW;
  }
  uses {
    interface HplMsp430UsciB as Usci;
  }
}
implementation {
  MSP430REG_NORACE(P3SEL);
  MSP430REG_NORACE(P5DIR);

/*
 * The MM4 is clocked at 8MHz.  (could go up to 16MHz)
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
 */

// #define SPI_400K_DIV 21
#define SPI_8MHZ_DIV    1
#define SPI_FULL_SPEED_DIV SPI_8MHZ_DIV

const msp430_spi_union_config_t sd_full_config = { {
  ubr		: SPI_8MHZ_DIV,         /* full speed */
  ucmode	: 0,			/* 3 pin master, no ste */
  ucmst		: 1,
  uc7bit	: 0,			/* 8 bit */
  ucmsb		: 1,			/* msb first, compatible with msp430 usart */
  ucckpl	: 0,			/* inactive state low */
  ucckph	: 1,			/* data captured on rising, changed falling */
  ucssel	: 2,			/* smclk */
  } };


#ifdef notdef
/*
 * exp5438_gps, 5438a, USCI, SPI
 * x5 usci configuration
 * interface to si446x chip
 */

const msp430_usci_config_t si446x_spi_config = {
  /*
   * UCCKPH: 1,         data captured on rising edge
   * UCCKPL: 0,         inactive state is low
   * UCMSB:  1,
   * UC7BIT: 0,         8 bit
   * UCMST:  1,
   * UCMODE: 0b00,      3 wire SPI
   * UCSYNC: 1
   * UCSSEL: SMCLK
   */
  ctl0 : (UCCKPH | UCMSB | UCMST | UCSYNC),
  ctl1 : UCSSEL__SMCLK,
  br0  : 2,			/* 8MHz -> 4 MHz */
  br1  : 0,
  mctl : 0,                     /* Always 0 in SPI mode */
  i2coa: 0
};

#endif


  async command void HW.sd_spi_init() {
    call HW.sd_spi_disable();
    call HW.sd_off();
  }

  async command void HW.sd_spi_enable() {
    /*
     * ideally we want to flip the pins back and reconfigure and/or
     * simply take it out of reset.  But the interface doesn't export
     * a simple configurator.
     */
//    SD_PINS_SPI;			// switch pins over
    call Usci.setModeSpi(&sd_full_config);
  }

  async command void HW.sd_spi_disable() {
    SD_PINS_INPUT;			// all data pins inputs
    call Usci.resetUsci_n();            // just leave in reset
  }

  async command void HW.sd_access_enable()      { }
  async command void HW.sd_access_disable()     { }
  async command bool HW.sd_access_granted()     { return TRUE; }
  async command bool HW.sd_check_access_state() { return TRUE; }

  /*
   * see HW.sd_off for problems.
   *
   * assumes pin state as follows:
   *
   *   p5.0 sd_pwr_off	1pO
   *   p3.1 sd_mosi	0pO
   *   p3.2 sd_miso	0pO
   *   p3.3 sd_sck	0pO
   *   p5.4 sd_csn      0pO
   *
   *   sd_csn  1pO (holds csn high, deselected) (starts to power).
   *   set pins to Module (mosi, miso, and sck)
   *   power up
   */

  async command void HW.sd_on() {
    SD_CSN = 1;				// make sure tristated
    SD_PWR_ON;				// turn on.
  }

  /*
   * turn sd_off and switch pins back to port (1pI) so we don't power the
   * chip prior to powering it off.
   */
  async command void HW.sd_off() {
    SD_CSN = 1;				// tri-state by deselecting
    SD_PWR_OFF;				// kill power
  }

  async command bool HW.isSDPowered() {
    return (mmP5out.sd_pwr_off == 0);
  }

  async command void    HW.sd_set_cs()          { SD_CSN = 0; }
  async command void    HW.sd_clr_cs()          { SD_CSN = 1; }
}
