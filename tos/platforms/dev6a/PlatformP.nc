/*
 * Copyright (c) 2016-2017 Eric B. Decker
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
 * Warning: many of these routines directly touch cpu registers
 * it is assumed that this is initilization code and interrupts are
 * off.
 *
 * @author Eric B. Decker
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
    interface SysReboot;
  }
  uses {
    interface Init as PlatformPins;
    interface Init as PlatformLeds;
    interface Init as PlatformClock;
    interface Init as PeripheralInit;
    interface OverWatchHardware as OWhw;
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


  async command void SysReboot.clear(sysreboot_t reboot_type) {
    switch (reboot_type) {
      default:
        return;
      case SYSREBOOT_REBOOT:
        RSTCTL->REBOOTRESET_CLR = RSTCTL_REBOOTRESET_CLR_CLR;
        return;
      case SYSREBOOT_OW_REQUEST:
        RSTCTL->HARDRESET_CLR = PRD_RESET_OW_REQ;
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


  /***************** Defaults ***************/
  default command error_t PeripheralInit.init() {
    return SUCCESS;
  }
}
