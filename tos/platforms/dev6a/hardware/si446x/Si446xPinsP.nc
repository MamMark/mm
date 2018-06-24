/*
 * Copyright (c) 2015, 2017 Eric B. Decker
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
#include "platform_pin_defs.h"

module Si446xPinsP {
  provides interface Si446xInterface as HW;
  uses interface HplMsp432PortInt as RadioNIRQ;
}
implementation {
  async command uint8_t  HW.si446x_cts()             { return SI446X_CTS_P; }
  async command uint8_t  HW.si446x_irqn()            { return SI446X_IRQN_P; }
  async command uint8_t  HW.si446x_sdn()             { return SI446X_SDN_IN; }
  async command uint8_t  HW.si446x_csn()             { return SI446X_CSN_IN; }
  async command void     HW.si446x_shutdown()        { SI446X_SHUTDOWN; }
  async command void     HW.si446x_unshutdown()      { SI446X_UNSHUT; }
  async command void     HW.si446x_set_cs()          { SI446X_CSN = 0; }
  async command void     HW.si446x_clr_cs()          { SI446X_CSN = 1; }
  async command void     HW.si446x_set_low_tx_pwr()  { }
  async command void     HW.si446x_set_high_tx_pwr() { }
  async command uint16_t HW.si446x_cap_val()         { return 0; }
  async command uint16_t HW.si446x_cap_control()     { return 0 ;}

  async command void HW.si446x_enableInterrupt() {
    /*
     * playing with the edge could generate an IFG which would trigger an
     * interrupt.  Clear after playing with the edge.
     */
    atomic {
      call RadioNIRQ.disable();
      call RadioNIRQ.edgeFalling();
      call RadioNIRQ.clear();
      call RadioNIRQ.enable();
    }
  }

  async command void HW.si446x_disableInterrupt() {
    atomic {
      call RadioNIRQ.disable();
    }
  }

  async command bool HW.si446x_isInterruptEnabled() {
    return call RadioNIRQ.isEnabled();
  }

  async event void RadioNIRQ.fired() {
    signal HW.si446x_interrupt();
  }
}
