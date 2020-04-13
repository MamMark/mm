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

#include "msp432usci.h"

/*
 * dev6a, msp432, USCI, SPI
 * msp432 usci configuration
 * interface to si446x chip
 */

const msp432_usci_config_t si446x_spi_config = {
  ctlw0 : (EUSCI_B_CTLW0_CKPH        | EUSCI_B_CTLW0_MSB  |
           EUSCI_B_CTLW0_MST         | EUSCI_B_CTLW0_SYNC |
           EUSCI_B_CTLW0_SSEL__SMCLK),
  brw   : MSP432_RADIO_DIV,     /* see platform_clk_defs */
  mctlw : 0,                    /* Always 0 in SPI mode */
  i2coa : 0
};

module Si446xSpiConfigP {
  provides interface Msp432UsciConfigure;
}
implementation {
  async command const msp432_usci_config_t *Msp432UsciConfigure.getConfiguration() {
    return &si446x_spi_config;
  }
}
