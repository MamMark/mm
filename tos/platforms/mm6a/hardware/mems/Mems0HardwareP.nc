/*
 * Copyright (c) 2017, 2019 Eric B. Decker
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
#include <lisxdh.h>

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

module Mems0HardwareP {
  provides {
    interface Msp432UsciConfigure;
    interface Init as PeriphInit;
    interface SpiBus;
    interface MemsStInterrupt as AccelInt1;
  }
  uses {
    interface Panic;
    interface Init   as SpiInit;
    interface SpiReg as AccelReg;
    interface HplMsp432PortInt as AccelInt1_Port;
  }
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

  async command void AccelInt1.enableInterrupt() {
    call AccelInt1_Port.disable();
    call AccelInt1_Port.edgeRising();
    call AccelInt1_Port.clear();
    call AccelInt1_Port.enable();
  }

  async command void AccelInt1.disableInterrupt() {
    call AccelInt1_Port.disable();
  }

  async command bool AccelInt1.isInterruptEnabled() {
    call AccelInt1_Port.isEnabled();
  }

  async event void AccelInt1_Port.fired() {
    signal AccelInt1.interrupt();
  }


  void accel_init() {
//    lis2dh12_ctrl_reg0_t reg0;
    lisx_ctrl_reg4_t     reg4;
    union {
      lisx_ctrl_reg5_t   x;
      uint8_t            bits;
    } reg5;
    lisx_fifo_ctrl_reg_t fifo_ctrl;

    /*
     * CR0:       90  turn off SDO_PU
     * CR4:       91  BDU (block data update), FS 00 (2g), self test, 4 wire
     * CR5:       40  ffo enable
     * fifo_ctrl: 49  fifo mode, fifo threshold
     */
//    reg0.rsvd_01     = 0;
//    reg0.sdo_pu_disc = 1;
//    call AccelReg.write(LISX_CTRL_REG0, (void *) &reg0, 1);

    reg4.sim = 1;
    reg4.st  = 0;
    reg4.hr  = 0;
    reg4.fs  = LISX_FS_2G;
    reg4.ble = 0;
    reg4.bdu = 1;
    call AccelReg.write(LISX_CTRL_REG4, (void *) &reg4, 1);

    reg5.bits      = 0;
    reg5.x.fifo_en = 1;
    call AccelReg.write(LISX_CTRL_REG5, (void *) &reg5, 1);

    fifo_ctrl.fth = 9;
    fifo_ctrl.tr  = 0;
    fifo_ctrl.fm  = LISX_FIFO_MODE;
    call AccelReg.write(LISX_FIFO_CTRL_REG, (void *) &fifo_ctrl, 1);
  }

  void gyro_init() {
    nop();
  }

  void mag_init() {
    nop();
  }


  command error_t PeriphInit.init() {
    call SpiInit.init();                /* first bring up the mems SPI bus */
    accel_init();                       /* then init the 3 devices */
    gyro_init();
    mag_init();
    return SUCCESS;
  }

  async event void Panic.hook() { }
}
