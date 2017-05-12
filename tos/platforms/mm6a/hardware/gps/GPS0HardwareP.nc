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
#include <panic.h>
#include <platform_panic.h>
#include <msp432.h>
#include <platform_clk_defs.h>

#if (MSP432_CLK != 16777216)
#warning MSP432_CLK other than 16777216
#endif

#ifndef PANIC_GPS
enum {
  __pcode_gps = unique(UQ_PANIC_SUBSYS)
};

#define PANIC_GPS __pcode_gps
#endif

module GPS0HardwareP {
  provides {
    interface Init;
    interface Gsd4eUHardware as HW;
  }
  uses {
    interface HplMsp432Usci    as Usci;
    interface HplMsp432UsciInt as Interrupt;
    interface Panic;
    interface Platform;
  }
}
implementation {

  enum {
    UART_MAX_BUSY_WAIT = 10000,                 /* 10ms max busy wait time */
  };


#define gps_panic(where, arg, arg1) do {                 \
    call Panic.panic(PANIC_GPS, where, arg, arg1, 0, 0); \
  } while (0)

#define  gps_warn(where, arg)      do { \
    call  Panic.warn(PANIC_GPS, where, arg, 0, 0, 0); \
  } while (0)

  /* Baud rate divisor equations
   *
   * N.Frac = BRCLK / bps
   * brw = N
   * BRCLK = 8Mi (8388608)
   * EUSCI_A_MCTLW_BRS_OFS = lookup[Frac]
   *
   * (see table on page 736 of SLAU356E - Revised Dec 2016)
   */


  /* BRCLK is SMCLK, assumed to be 8MiHz */
  const msp432_usci_config_t gps_4800_config = {
    ctlw0 : EUSCI_A_CTLW0_SSEL__SMCLK,
    brw   : 1747,
    mctlw : (0 << EUSCI_A_MCTLW_BRF_OFS) |
            (0xb5 << EUSCI_A_MCTLW_BRS_OFS),
    i2coa : 0
  };


  /* BRCLK is SMCLK, assumed to be 8MiHz */
  const msp432_usci_config_t gps_9600_config = {
    ctlw0 : EUSCI_A_CTLW0_SSEL__SMCLK,
    brw   : 873,
    mctlw : (0 << EUSCI_A_MCTLW_BRF_OFS) |
            (0xee << EUSCI_A_MCTLW_BRS_OFS),
    i2coa : 0
  };


  const msp432_usci_config_t gps_57600_config = {
    ctlw0 : EUSCI_A_CTLW0_SSEL__SMCLK,
    brw   : 145,
    mctlw : (0 << EUSCI_A_MCTLW_BRF_OFS) |
            (0xb5 << EUSCI_A_MCTLW_BRS_OFS),
    i2coa : 0
  };


  const msp432_usci_config_t gps_115200_config = {
    ctlw0 : EUSCI_A_CTLW0_SSEL__SMCLK,
    brw   : 72,
    mctlw : (0 << EUSCI_A_MCTLW_BRF_OFS) |
            (0xee << EUSCI_A_MCTLW_BRS_OFS),
    i2coa : 0
  };


  const msp432_usci_config_t gps_307200_config = {
    ctlw0 : EUSCI_A_CTLW0_SSEL__SMCLK,
    brw   : 27,
    mctlw : (0 << EUSCI_A_MCTLW_BRF_OFS) |
            (0x25 << EUSCI_A_MCTLW_BRS_OFS),
    i2coa : 0
  };


  const msp432_usci_config_t gps_1228800_config = {
    ctlw0 : EUSCI_A_CTLW0_SSEL__SMCLK,
    brw   : 6,
    mctlw : (0 << EUSCI_A_MCTLW_BRF_OFS) |
            (0xbf << EUSCI_A_MCTLW_BRS_OFS),
    i2coa : 0
  };

  norace uint8_t *m_tx_buf;
  norace uint16_t m_tx_len;

  norace uint8_t *m_rx_buf;
  norace uint16_t m_rx_len;
  norace uint32_t m_tx_idx, m_rx_idx;

  command error_t Init.init() {
    call Usci.enableModuleInterrupt();
    GSD4E_PINS_MODULE;			/* connect from the UART */
    return SUCCESS;
  }


  async command void HW.gps_set_on_off() {
    GSD4E_ONOFF = 1;
  }

  async command void HW.gps_clr_on_off() {
    GSD4E_ONOFF = 0;
  }

  async command void HW.gps_set_reset() {
    GSD4E_CTS = 1;              /* say we want UART mode */
    GSD4E_RESETN_OUTPUT;
    GSD4E_RESETN = 0;
  }

  async command void HW.gps_clr_reset() {
    GSD4E_RESETN = 1;
    GSD4E_RESETN_FLOAT;
  }

  async command bool HW.gps_awake() {
    return GSD4E_AWAKE_P;
  }

  async command void HW.gps_pwr_on() {
    GSD4E_PINS_MODULE;			/* connect from the UART */
  }

  async command void HW.gps_pwr_off() {
    GSD4E_PINS_PORT;                    /* disconnect from the UART */
  }

  /*
   * gps_tx_finnish: wait for tx to finish
   *
   * input: byte_delay (in us) for last byte to leave
   *
   * tx_finnish first makes sure that the TXBUF is empty.  ie. that the
   * byte in TXBUF has actually been transferred into the shift register
   * and is on its way out.
   *
   * Then if byte_delay is set it will delay some more.  byte_delay is
   * a value used to let the last byte actually leave the shift register.
   * This is used prior to changing communications configurations.
   */
  async command void HW.gps_tx_finnish(uint32_t byte_delay) {
    uint32_t t0, t1;

    t0 = call Platform.usecsRaw();
    while (!call Usci.isTxIntrPending()) {
      t1 = call Platform.usecsRaw();
      if (t1 - t0 > UART_MAX_BUSY_WAIT) {
	gps_panic(1, t1, t0);
	return;
      }
    }
    t0 = call Platform.usecsRaw();
    while (1) {
      t1 = call Platform.usecsRaw();
      if (t1 - t0 > byte_delay)
        return;
    }
  }

  async command void HW.gps_speed_di(uint32_t speed) {
    const msp432_usci_config_t *config = NULL;

    switch(speed) {
      case    4800:     config =    &gps_4800_config;    break;
      case    9600:     config =    &gps_9600_config;    break;
      case   57600:     config =   &gps_57600_config;    break;
      case  115200:     config =  &gps_115200_config;    break;
      case  307200:     config =  &gps_307200_config;    break;
      case 1228800:     config = &gps_1228800_config;    break;
      default:          gps_panic(2, speed, 0);          break;
    }
    if (!config)
	gps_panic(1, speed, 0);
    call Usci.configure(config, FALSE);

    /* Usci.configure (via reset) turns off all interrupts and
     * cleans all IFGs out.
     */

  }

  async command void HW.gps_rx_int_enable() {
    call Usci.enableRxIntr();
  }

  async command void HW.gps_rx_int_disable() {
    call Usci.disableRxIntr();
  }

  async command error_t HW.gps_receive_block(uint8_t *ptr, uint16_t len) {
    if (!len || !ptr)
      return FAIL;

    if (m_rx_buf)
      return EBUSY;

    m_rx_len = len;
    m_rx_idx = 0;
    m_rx_buf = ptr;
    call HW.gps_rx_int_enable();
    return SUCCESS;
  }

  async command void    HW.gps_receive_block_stop() {
    m_rx_buf = NULL;
  }

  async command void    HW.gps_rx_off() { }
  async command void    HW.gps_rx_on()  { }

  async command error_t HW.gps_send_block(uint8_t *ptr, uint16_t len) {
    if (!len || !ptr)
      return FAIL;

    if (m_tx_buf)
      return EBUSY;

    m_tx_len = len;
    m_tx_idx = 0;
    m_tx_buf = ptr;
    /*
     * On start up UCTXIFG should be asserted, so enabling the TX interrupt
     * should cause the ISR to get invoked.
     *
     * The interrupt handler takes care of UCTXCPTIFG.
     */
    call Usci.enableTxIntr();
    return SUCCESS;
  }

  async command void    HW.gps_send_block_stop() {
    call Usci.disableTxIntr();
    m_tx_buf = NULL;
  }

  async event void Interrupt.interrupted(uint8_t iv) {
    uint8_t data;
    uint8_t *buf;

    switch(iv) {
      case MSP432U_IV_RXIFG:
        data = call Usci.getRxbuf();
        if (m_rx_buf) {
          m_rx_buf[m_rx_idx++] = data;
          if (m_rx_idx >= m_rx_len) {
            buf = m_rx_buf;
            m_rx_buf = NULL;
            signal HW.gps_receive_block_done(buf, m_rx_len, SUCCESS);
          }
        } else
          signal HW.gps_byte_avail(data);
        return;

      case MSP432U_IV_TXIFG:
        if (m_tx_buf == NULL) {
          call Usci.disableTxIntr();
          return;
        }

        data = m_tx_buf[m_tx_idx++];
        call Usci.clrTxComplete();
        call Usci.setTxbuf(data);
        if (m_tx_idx >= m_tx_len) {
          buf = m_tx_buf;
          call Usci.disableTxIntr();
          m_tx_buf = NULL;
          signal HW.gps_send_block_done(buf, m_tx_len, SUCCESS);
        }
        return;

      default:
        break;
    }
  }

  async event void Panic.hook() { }
}
