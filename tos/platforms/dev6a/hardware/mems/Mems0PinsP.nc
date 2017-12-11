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
 */

/**
 * @author Eric B. Decker <cire831@gmail.com>
 */

#include "hardware.h"
#include <panic.h>
#include <platform_panic.h>
#include "platform_pin_defs.h"

#ifndef PANIC_SNS
enum {
  __pcode_sns = unique(UQ_PANIC_SUBSYS)
};

#define PANIC_SNS __pcode_sns
#endif

#include "msp432usci.h"

/*
 * dev6a, msp432, USCI, SPI
 * msp432 usci configuration
 * interface to mems bus
 */

const msp432_usci_config_t mems_spi_config = {
  ctlw0 : (EUSCI_B_CTLW0_CKPL        | EUSCI_B_CTLW0_MSB  |
           EUSCI_B_CTLW0_MST         | EUSCI_B_CTLW0_SYNC |
           EUSCI_B_CTLW0_SSEL__SMCLK),
  brw   : MSP432_MEMS_DIV,     /* see platform_clk_defs */
  mctlw : 0,                   /* Always 0 in SPI mode  */
  i2coa : 0
};

module Mems0PinsP {
  provides {
    interface SpiBus;
    interface Msp432UsciConfigure;
  }
  uses interface Panic;
}
implementation {
  async command void SpiBus.set_cs(uint8_t mems_id) {
    switch(mems_id) {
      default:
        call Panic.panic(PANIC_SNS, 1, mems_id, 0, 0, 0);
      case MEMS0_ID_ACCEL:
        MEMS0_ACCEL_CSN = 0;
    }
  }

  async command void SpiBus.clr_cs(uint8_t mems_id) {
    switch(mems_id) {
      default:
        call Panic.panic(PANIC_SNS, 1, mems_id, 0, 0, 0);
      case MEMS0_ID_ACCEL:
        MEMS0_ACCEL_CSN = 1;
    }
  }

  async command const msp432_usci_config_t *Msp432UsciConfigure.getConfiguration() {
    return &mems_spi_config;
  }

  async event void Panic.hook() { }
}
