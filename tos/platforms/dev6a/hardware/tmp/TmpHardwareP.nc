/*
 * Copyright (c) 2017 Eric B. Decker
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
 * @author Eric B. Decker <cire831@gmail.com>
 */

#include <hardware.h>
#include "tmp1x2.h"

module TmpHardwareP {
  provides interface Init;
  uses {
    interface ResourceDefaultOwner;
    interface Timer<TMilli>;
    interface HplMsp432Usci    as Usci;
  }
}
implementation {

/*
 * The dev6a main cpu clock is 16MiHz, SMCLK (for periphs) is clocked at
 * 8MiHz.  The dev6a is a TI msp432p401r (exp-msp432p401r launch pad) dev
 * board with added mm6a peripherals.
 *
 * We run the i2c bus at 400KHz which gives us a byte time of 20us.
 *
 * Normal operation occurs at 8MiHz.  8MiHz/400KHz => 21 with some error ~0.1%.
 * The actual divisor is set in platform_clk_defs.h.  MSP432_TMP_DIV.
 *
 * Dev6a, msp432, USCI, I2C
 * master, mode 3 (i2c), sync, use SMCLK
 *
 * UCMST:  1,
 * UCMODE: 0b11,      i2c
 * UCSYNC: 1
 * UCSSEL: SMCLK
 */

const msp432_usci_config_t tmp_i2c_config = {
  ctlw0 : (  EUSCI_B_CTLW0_MST  | EUSCI_B_CTLW0_MODE_3 |
             EUSCI_B_CTLW0_SYNC | EUSCI_B_CTLW0_SSEL__SMCLK),
  brw   : MSP432_TMP_DIV,       /* see platform_clk_defs */
  mctlw : 0,                    /* Always 0 in SPI mode */
  i2coa : 0
};


  /* for PeripheralInit */
  command error_t Init.init() {
    call Usci.configure(&tmp_i2c_config, FALSE);

    /* we don't use interrupts, leave them off */
    return SUCCESS;
  }

  /*
   * ResourceDefaultOwner.granted: power down the TMP bus.
   *
   * reconfigure connections to the TMP bus as input to avoid powering any
   * chips and power off.
   */

  async event void ResourceDefaultOwner.granted() {
    TMP_PINS_PORT;
    TMP_I2C_PWR_OFF;
  }

  void task tmp_timer_task() {
    call Timer.startOneShot(TMP1X2_PWR_ON_DELAY);
  }


  /*
   * someone wants the TMP bus, turn it on.
   *
   * turn on power and reconfigure the pins to connect to the eUSCI
   *
   * We also want to wait for TMP1X2_PWR_ON_DELAY (35 ms) before letting
   * the arbiter issue the grant.
   */
  async event void ResourceDefaultOwner.requested() {
    TMP_I2C_PWR_ON;
    TMP_PINS_MODULE;
    post tmp_timer_task();
  }

  event void Timer.fired() {
    call ResourceDefaultOwner.release();
  }

  async event void ResourceDefaultOwner.immediateRequested() {
    TMP_I2C_PWR_ON;
    TMP_PINS_MODULE;
    call ResourceDefaultOwner.release();
  }
}
