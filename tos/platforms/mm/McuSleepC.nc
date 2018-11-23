/*
 * Copyright (c) 2018 Eric B. Decker
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
 * FOR A PARTICULAR PURPOSE ARE DISCLAIMED.  IN NO EVENT SHALL STANFORD
 * UNIVERSITY OR ITS CONTRIBUTORS BE LIABLE FOR ANY DIRECT, INDIRECT,
 * INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES
 * (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR
 * SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION)
 * HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT,
 * STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE)
 * ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED
 * OF THE POSSIBILITY OF SUCH DAMAGE.
 *
 * @author Eric B. Decker <cire831@gmail.com>
 */

#include "hardware.h"
#include <rtctime.h>

module McuSleepC {
  provides {
    interface McuSleep;                 /* external */
    interface McuPowerState;            /* external */
  }
  uses {
    interface McuPowerOverride;         /* external */

    interface Platform;                 /* Platform wires */
    interface CoreTime;                 /* Platform wires */
  }
}
implementation {
  norace mcu_power_t m_power_state;

  /*
   * McuSleep.sleep() is always called from within an
   * atomic block.  This avoids the race condition where
   * the interrupt that would take us out of deep sleep
   * occurs prior to the WFE.
   */
  async command void McuSleep.sleep() {
    SCB->SCR &= ~SCB_SCR_SLEEPDEEP_Msk;
    m_power_state = call McuPowerOverride.lowestState();
    if (m_power_state == POWER_DEEP_SLEEP)
      call CoreTime.initDeepSleep();

    __nesc_enable_interrupt();
    __DSB();
    __WFE();
    asm volatile("" : : : "memory");
    __nesc_disable_interrupt();
  }

  default async command mcu_power_t McuPowerOverride.lowestState() {
    return MSP432_POWER_SLEEP;
  }

  async command void McuSleep.irq_preamble() {
    call CoreTime.irq_preamble();
  }

  async command void McuSleep.irq_postamble() { }
  async command void McuPowerState.update()   { }
}
