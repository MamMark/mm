/*
 * Copyright (c) 2016-2018 Eric B. Decker
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
#include <platform_reset_defs.h>
#include <platform_version.h>
#include <sysreboot.h>

#define BOOT_MAJIK 0x01021910
#define FUBAR_MAX 0xffff
noinit uint32_t boot_majik;
noinit uint16_t boot_count;

module PlatformP {
  provides {
    interface Init;
    interface Platform;
    interface PlatformNodeId;
    interface SysReboot;
  }
  uses {
    interface Init as PlatformPins;
    interface Init as PlatformLeds;
    interface Init as PlatformClock;
    interface Init as PeripheralInit;
  }
}

implementation {
  command error_t Init.init() {
    call PlatformLeds.init();   // Initializes the Leds
    call PeripheralInit.init();
    return SUCCESS;
  }


  async command error_t  SysReboot.reboot(sysreboot_t reboot_type) {
    switch (reboot_type) {
      case SYSREBOOT_REBOOT:
        SYSCTL->REBOOT_CTL = (PRD_RESET_KEY | SYSCTL_REBOOT_CTL_REBOOT);
        break;
      case SYSREBOOT_POR:
        SYSCTL_Boot->RESET_REQ = (PRD_RESET_KEY | SYSCTL_RESET_REQ_POR);
        break;
      case SYSREBOOT_HARD:
        RSTCTL->RESET_REQ = (PRD_RESET_KEY | PRD_RESET_HARD);
        break;
      case SYSREBOOT_SOFT:
        RSTCTL->RESET_REQ = (PRD_RESET_KEY | PRD_RESET_SOFT);
        break;
      case SYSREBOOT_OW_REQUEST:
        RSTCTL->HARDRESET_SET = PRD_RESET_OW_REQ;
        break;
      default:
        return FAIL;
    }
    return SUCCESS;
  }


  async command error_t  SysReboot.soft_reboot(sysreboot_t reboot_type) {
    switch (reboot_type) {
      case SYSREBOOT_REBOOT:
      case SYSREBOOT_POR:
      case SYSREBOOT_HARD:
      case SYSREBOOT_SOFT:
        RSTCTL->RESET_REQ = (PRD_RESET_KEY | PRD_RESET_SOFT);
        break;
      case SYSREBOOT_OW_REQUEST:
        RSTCTL->SOFTRESET_SET = PRD_RESET_OW_REQ;
        break;
      default:
        return FAIL;
    }
    return SUCCESS;
  }


  async command void SysReboot.clear(sysreboot_t reboot_type) {
    switch (reboot_type) {
      default:
        return;
      case SYSREBOOT_REBOOT:
        RSTCTL->REBOOTRESET_CLR = RSTCTL_REBOOTRESET_CLR_CLR;
        return;
      case SYSREBOOT_OW_REQUEST:
        RSTCTL->HARDRESET_CLR = PRD_RESET_OW_REQ;
        RSTCTL->SOFTRESET_CLR = PRD_RESET_OW_REQ;
        return;
    }
  }


  async command void SysReboot.flush() {
    signal SysReboot.shutdown_flush();
  }


  /* T32 is a count down so negate it */
  async command uint32_t Platform.usecsRaw()       { return (1-(TIMER32_1->VALUE))/MSP432_T32_USEC_DIV; }
  async command uint32_t Platform.usecsRawSize()   { return 32; }
  async command uint32_t Platform.jiffiesRaw()     { return (TIMER_A1->R); }
  async command uint32_t Platform.jiffiesRawSize() { return 16; }

  async command bool     Platform.set_unaligned_traps(bool set_on) {
    bool unaligned_on;

    atomic {
      unaligned_on = FALSE;
      if (SCB->CCR & SCB_CCR_UNALIGN_TRP_Msk)
        unaligned_on = TRUE;
      if (set_on)
        SCB->CCR |= SCB_CCR_UNALIGN_TRP_Msk;
      else
        SCB->CCR &= ~(SCB_CCR_UNALIGN_TRP_Msk);
      __ISB();
    }
    return unaligned_on;
  }


  /**
   * PlatformNodeId.node_id
   *
   * return a pointer to a 6 byte random number that we can
   * use as both our serial_number as well as our network node_id.
   *
   * The msp432 provides a 128 bit (we use the first 48 bits, 6 bytes)
   * random number.  This shows up at address 0x0020_1120 but we
   * reference it using the definitions from the processor header.
   */
  async command uint8_t *PlatformNodeId.node_id(unsigned int *lenp) {
    if (lenp)
      *lenp = 6;
    return (uint8_t *) &TLV->RANDOM_NUM_1;
  }

  /***************** Defaults ***************/
  default command error_t PeripheralInit.init() {
    return SUCCESS;
  }
}
