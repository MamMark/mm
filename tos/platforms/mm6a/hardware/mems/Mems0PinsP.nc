/*
 * Copyright (c) 2017 Eric B. Decker
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
 * mm6a, msp432, USCI, SPI
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
      case MEMS0_ID_ACCEL: MEMS0_ACCEL_CSN = 0; break;
      case MEMS0_ID_GYRO:  MEMS0_GYRO_CSN  = 0; break;
      case MEMS0_ID_MAG:   MEMS0_MAG_CSN   = 0; break;
    }
  }

  async command void SpiBus.clr_cs(uint8_t mems_id) {
    switch(mems_id) {
      default:
        call Panic.panic(PANIC_SNS, 1, mems_id, 0, 0, 0);
      case MEMS0_ID_ACCEL: MEMS0_ACCEL_CSN = 1; break;
      case MEMS0_ID_GYRO:  MEMS0_GYRO_CSN  = 1; break;
      case MEMS0_ID_MAG:   MEMS0_MAG_CSN   = 1; break;
    }
  }

  async command const msp432_usci_config_t *Msp432UsciConfigure.getConfiguration() {
    return &mems_spi_config;
  }

  async event void Panic.hook() { }
}
