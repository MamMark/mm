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
#include <platform.h>

#define BOOT_MAJIK 0x01021910

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
    interface LocalTime<TMilli>;
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


  async command uint32_t Platform.localTime()      { return call LocalTime.get(); }

  /* T32 is a count down so negate it */
  async command uint32_t Platform.usecsRaw()       { return (1-(TIMER32_1->VALUE))/MSP432_T32_USEC_DIV; }
  async command uint32_t Platform.usecsRawSize()   { return 32; }

  uint32_t __platform_usecsRaw() @C() @spontaneous() {
    return call Platform.usecsRaw();
  }

  async command uint32_t Platform.usecsExpired(uint32_t t_base, uint32_t limit) {
    uint32_t t_new;

    t_new = call Platform.usecsRaw();
    if (t_new - t_base > limit)
      return t_new;
    return 0;
  }

  /* TA1 is async wrt the main cpu clock.  majority element time. */
  async command uint32_t Platform.jiffiesRaw()     {
    uint16_t t0, t1;

    t0 = TIMER_A1->R; t1 = TIMER_A1->R;
    if (t0 == t1)     return t0;

    t0 = TIMER_A1->R;
    if (t0 == t1)     return t0;

    t0 = TIMER_A1->R;
    return t0;
  }

  async command uint32_t Platform.jiffiesRawSize() { return 16; }

  uint32_t __platform_jiffiesRaw() @C() @spontaneous() {
    return call Platform.jiffiesRaw();
  }


  async command uint32_t Platform.jiffiesExpired(uint32_t t_base,
                                                 uint32_t limit) {
    uint32_t t_new;

    t_new = call Platform.jiffiesRaw();
    if (t_new - t_base > limit)
      return t_new;
    return 0;
  }


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
   * Platform.getInterruptPriority
   * Interrupt priority assignment
   *
   * The mm6a/dev6a are based on the ti msp432/cortex-4mf which have 3 bits
   * of interrupt priority.  0 is the highest, 7 the lowest.
   *
   * platform.h define the IRQNs and priorities.
   */
  async command int Platform.getIntPriority(int irq_number) {
    switch (irq_number) {
      default:
        return IRQ_DEFAULT_PRIORITY;

      case CS_IRQn:                     /* clock faults */
      case RTC_C_IRQn:                  /* RTC interrupts */
        return 0;                       /* highest priority */
      case GPS_IRQN:
        return GPS_IRQ_PRIORITY;        /* gps0   */
      case RADIO_IRQN:
        return RADIO_IRQ_PRIORITY;      /* si446x */
    }
  }


  /**
   * Platform.node_id
   *
   * return a pointer to a 6 byte random number that we can
   * use as both our serial_number as well as our network node_id.
   *
   * The msp432 provides a 128 bit (we use the first 48 bits, 6 bytes)
   * random number.  This shows up at address 0x0020_1120 but we
   * reference it using the definitions from the processor header.
   */
  async command uint8_t *Platform.node_id(unsigned int *lenp) {
    if (lenp)
      *lenp = PLATFORM_SERIAL_NUM_SIZE;
    return (uint8_t *) &TLV->RANDOM_NUM_1;
  }


  /***************** Defaults ***************/
  default command error_t PeripheralInit.init() {
    return SUCCESS;
  }
}
