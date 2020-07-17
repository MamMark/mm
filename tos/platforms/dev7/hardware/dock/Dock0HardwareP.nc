/*
 * Copyright (c) 2020      Eric B. Decker
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

#include <msp432.h>
#include <hardware.h>
#include <platform.h>
#include <panic.h>
#include <platform_panic.h>
#include <dockcomm.h>

#ifndef PANIC_DOCK
enum {
  __pcode_dock = unique(UQ_PANIC_SUBSYS)
};

#define PANIC_DOCK __pcode_dock
#endif

module Dock0HardwareP {
  provides {
    interface Init as Dock0PeriphInit;
    interface DockCommHardware as HW;
  }
  uses {
    interface Boot;                     /* SysBootC */
    interface HplMsp432Usci    as Usci;
    interface HplMsp432PortInt as AttnIRQ;
    interface Panic;
    interface Platform;
  }
}
implementation {

#define dc_panic(where, arg, arg1) do {                 \
    call Panic.panic(PANIC_DOCK, where, arg, arg1, 0, 0); \
  } while (0)

#define  dc_warn(where, arg)      do { \
    call  Panic.warn(PANIC_DOCK, where, arg, 0, 0, 0); \
  } while (0)


  norace uint8_t *m_tx_buf;
  norace uint16_t m_tx_len;

  norace bool     m_rx_active;          /* true if really receiving */
  norace uint8_t *m_rx_buf;
  norace uint16_t m_rx_len;
  norace uint32_t m_tx_idx, m_rx_idx;

  const msp432_usci_config_t dock_spi_config = {
    ctlw0 :
            (EUSCI_A_CTLW0_CKPH        | EUSCI_A_CTLW0_MSB  |
                                         EUSCI_A_CTLW0_SYNC |
             EUSCI_A_CTLW0_SSEL__SMCLK),
    brw   : 1,                          /* not used, slave      */
    mctlw : 0,                          /* Always 0 in SPI mode */
    i2coa : 0
  };


  command error_t Dock0PeriphInit.init() {
    call Usci.configure(&dock_spi_config, FALSE);
    return SUCCESS;
  }


  /*
   * dc_set_srsp: set response.
   *
   * If inside the packet set the byte being returned, this
   * is the intermediate status.  Eventually, this will also
   * become the SRSP byte.
   *
   * If at the end sets the SRSP byte.
   */
  command void HW.dc_set_srsp(uint8_t byte) {
  }

  command error_t HW.dc_send_block(uint8_t *ptr, uint16_t len) {
    return FAIL;
  }

  command void    HW.dc_send_block_stop() {
  }


  command uint8_t HW.dc_attn_pin() {
    return DC_ATTN_P;
  }

  /*
   * enable/disable the attn interrupt.
   */
  command void HW.dc_attn_enable() {
    atomic {
      call AttnIRQ.disable();
      call AttnIRQ.edgeRising();
      call AttnIRQ.clear();
      call AttnIRQ.enable();
    }
  }

  command void HW.dc_attn_disable() {
    call AttnIRQ.disable();
  }


  command bool HW.dc_attn_enabled() {
    return call AttnIRQ.isEnabled();
  }

  task void DC_Catch_task() {
    uint8_t data;

    atomic {
      signal HW.dc_atattn();
      while (call HW.dc_attn_pin()) {
        if (call Usci.isRxIntrPending()) {
          data = call Usci.getRxbuf();
          signal HW.dc_byte_avail(data);
        }
      }
      signal HW.dc_unattn();
    }
  }

  event void Boot.booted() {
    call HW.dc_attn_enable();
    if (call HW.dc_attn_pin())
      post DC_Catch_task();
  }

  async event void AttnIRQ.fired() {
    post DC_Catch_task();
  }

  async event void Panic.hook() { }
}
