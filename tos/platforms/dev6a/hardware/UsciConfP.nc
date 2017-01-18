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
 *
 * @author Eric B. Decker <cire831@gmail.com>
 */

#include <msp432usci.h>
#include <platform_clk_defs.h>

module UsciConfP {
  provides {
    interface Msp432UsciConfigure as GpsConf;
  }
}
implementation {

  /* currently set up for a GPS, Antenova, UART @ 9600, MCLK 16Mi, SMCLK 8Mi */
  /* for 1228800, brw 6, brs 0xbf */
  const msp432_usci_config_t gps_config = {
    ctlw0 : EUSCI_A_CTLW0_SSEL__SMCLK,
    brw   : 873,
    mctlw : (0 << EUSCI_A_MCTLW_BRF_OFS) |
            (0xee << EUSCI_A_MCTLW_BRS_OFS),
    i2coa : 0
  };

#ifdef notdef
  /* currently set up for a GPS, Antenova, UART @ 9600, MCLK 32Mi, SMCLK 16Mi */
  const msp432_usci_config_t gps_config = {
    ctlw0 : EUSCI_A_CTLW0_SSEL__SMCLK,
    brw   : 1747,
    mctlw : (0 << EUSCI_A_MCTLW_BRF_OFS) |
            (0xb5 << EUSCI_A_MCTLW_BRS_OFS),
    i2coa : 0
  };
#endif

  async command const msp432_usci_config_t *GpsConf.getConfiguration() {
    return &gps_config;
  }
}
