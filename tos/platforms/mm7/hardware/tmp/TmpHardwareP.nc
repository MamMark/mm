/*
 * Copyright (c) 2017, 2019, 2021 Eric B. Decker
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

#include <hardware.h>
#include "tmp1x2.h"

module TmpHardwareP {
  provides {
    interface Init as PeriphInit;
    interface TmpHardware;
  }
  uses {
    interface Timer<TMilli>;
    interface HplMsp432Usci    as Usci;
  }
}
implementation {
  uint8_t req_dev_addr;

/*
 * The mm7 main cpu clock is 16 MiHz, SMCLK (for periphs) is clocked at
 * 8 MiHz.
 *
 * We run the i2c bus at 400KHz which gives us a byte time of 20us.
 *
 * The eUSCI is clocked at 8MiHz.  8MiHz/400KHz => 21 with some error ~0.1%.
 * The actual divisor is set in platform_clk_defs.h.  MSP432_TMP_DIV.
 *
 * mm7, msp432, USCI, I2C
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
  command error_t PeriphInit.init() {
    call TmpHardware.tmp_off(0x48);
    call Usci.configure(&tmp_i2c_config, FALSE);

    /* we don't use interrupts, leave them off */
    return SUCCESS;
  }

  command error_t TmpHardware.tmp_on(uint8_t dev_addr) {
    TMP_I2C_PWR_ON;
    BITBAND_PERI(TMP_SDA_PORT->SEL0, TMP_SDA_PIN) = 1;
    BITBAND_PERI(TMP_SCL_PORT->SEL0, TMP_SCL_PIN) = 1;
    req_dev_addr = dev_addr;
    call Timer.startOneShot(TMP1X2_PWR_ON_DELAY);
    return SUCCESS;
  }

  command error_t TmpHardware.tmp_off(uint8_t dev_addr) {
    req_dev_addr = 0;
    TMP_I2C_PWR_OFF;
    BITBAND_PERI(TMP_SDA_PORT->SEL0, TMP_SDA_PIN) = 0;
    BITBAND_PERI(TMP_SCL_PORT->SEL0, TMP_SCL_PIN) = 0;
    call Timer.stop();
    return EOFF;
  }

  command bool TmpHardware.isTmpPowered(uint8_t dev_addr) {
    if (TMP_GET_PWR_STATE)
      return TRUE;
    return FALSE;
  }

  event void Timer.fired() {
    uint8_t rda;

    rda = req_dev_addr;
    req_dev_addr = 0;
    signal TmpHardware.tmp_on_done(SUCCESS, rda);
  }
}
