/*
 * Copyright (c) 2021 Eric B. Decker
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
#include <platform_pin_defs.h>

#ifndef PANIC_SNS
enum {
  __pcode_sns = unique(UQ_PANIC_SUBSYS)
};

#define PANIC_SNS __pcode_sns
#endif

#include "msp432usci.h"

/*
 * mm7, msp432, USCI, SPI
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

module Mems0HardwareP {
  provides {
    interface Msp432UsciConfigure;
    interface Init as PeriphInit;
    interface SpiBus;
    interface MemsStInterrupt as LSM6Int1;
  }
  uses {
    interface Panic;
    interface Init   as SpiInit;
    interface Init   as LSM6Init;
//  interface Init   as LPS22Init;
    interface HplMsp432PortInt as LSM6Int1Port;
  }
}
implementation {
  async command void SpiBus.set_cs(uint8_t mems_id) {
    switch(mems_id) {
      default:
        call Panic.panic(PANIC_SNS, 1, mems_id, 0, 0, 0);
      case MEMS0_ID_LSM6:  MEMS0_LSM6_CSN  = 0; break;
      case MEMS0_ID_LPS22: MEMS0_LPS22_CSN = 0; break;
    }
  }

  async command void SpiBus.clr_cs(uint8_t mems_id) {
    switch(mems_id) {
      default:
        call Panic.panic(PANIC_SNS, 1, mems_id, 0, 0, 0);
      case MEMS0_ID_LSM6:  MEMS0_LSM6_CSN  = 1; break;
      case MEMS0_ID_LPS22: MEMS0_LPS22_CSN = 1; break;
    }
  }

  async command const msp432_usci_config_t *Msp432UsciConfigure.getConfiguration() {
    return &mems_spi_config;
  }

  async command void LSM6Int1.enableInterrupt() {
    call LSM6Int1Port.enable();
  }

  async command void LSM6Int1.disableInterrupt() {
    call LSM6Int1Port.disable();
  }

  async command void LSM6Int1.clearInterrupt() {
    call LSM6Int1Port.clear();
  }

  async command bool LSM6Int1.isInterruptEnabled() {
    call LSM6Int1Port.isEnabled();
  }

  async event void LSM6Int1Port.fired() {
    signal LSM6Int1.interrupt();
  }


  command error_t PeriphInit.init() {
    atomic {
      call LSM6Int1Port.disable();
      call LSM6Int1Port.edgeRising();
      call LSM6Int1Port.clear();
    }
    call SpiInit.init();                /* first bring up the mems SPI bus */
    call LSM6Init.init();               /* init the LSM6 registers */
    return SUCCESS;
  }

  async event void Panic.hook() { }
}
