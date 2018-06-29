/*
 * Copyright (c) 2018 Eric B. Decker
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

#include <rtc.h>
#include <rtctime.h>
#include <platform_panic.h>
#include <overwatch.h>

#ifndef PANIC_TIME
enum {
  __pcode_time = unique(UQ_PANIC_SUBSYS)
};

#define PANIC_TIME __pcode_time
#endif

typedef enum {
  CTS_IDLE = 0,
  CTS_FIRST,
  CTS_CYCLE,
} ct_state_t;

typedef struct {
  uint32_t    usec;
  uint16_t    ta_r;
  uint16_t    ps;
  int16_t     arg;
  ct_state_t  state;
} ct_rec_t;

#define CT_ENTRIES 128
        ct_rec_t core_time_trace[CT_ENTRIES];
norace  uint32_t ct_nxt;

uint32_t ct_last_usec;
int32_t  ct_last_delta;

module CoreTimeP {
  provides {
    interface CoreTime;
    interface Boot as Booted;           /* Out boot */
  }
  uses {
    interface Boot;                     /* In Boot */
    interface Timer<TMilli> as CTimer;
    interface OverWatch;
    interface Platform;
    interface Panic;
  }
}
implementation {

  /* shared, norace.  its been looked at */
  norace ct_state_t ct_state;
  norace uint32_t   ct_count;

  ct_rec_t *get_core_rec() {
    ct_rec_t *rec;
    uint16_t ps0, ps1;

    rec = &core_time_trace[ct_nxt++];
    if (ct_nxt >= CT_ENTRIES)
      ct_nxt = 0;
    rec->usec = call Platform.usecsRaw();
    rec->ta_r = call Platform.jiffiesRaw();
    rec->state = ct_state;
    do {
      ps0 = RTC_C->PS;
      ps1 = RTC_C->PS;
      if (ps0 == ps1)
        break;
      ps0 = RTC_C->PS;
      if (ps0 == ps1)
        break;
      ps0 = RTC_C->PS;
    } while (0);
    rec->ps = ps0;
    return rec;
  }

  event void Boot.booted() {
    atomic {
      NVIC_SetPriority(CS_IRQn, call Platform.getIntPriority(CS_IRQn));
      NVIC_EnableIRQ(CS_IRQn);
      CS->IE = CS_IE_DCOR_OPNIE | CS_IE_LFXTIE;

      NVIC_SetPriority(RTC_C_IRQn, call Platform.getIntPriority(RTC_C_IRQn));
      NVIC_EnableIRQ(RTC_C_IRQn);
      /*
       * unlock the RTC and set the RTCOFIE.  Osc Fault
       */
      RTC_C->CTL0 = (RTC_C->CTL0 & ~RTC_C_CTL0_KEY_MASK) | RTC_C_KEY;
      BITBAND_PERI(RTC_C->CTL0, RTC_C_CTL0_OFIE_OFS) = 1;
      BITBAND_PERI(RTC_C->CTL0, RTC_C_CTL0_KEY_OFS) = 0;    /* close lock */
    }
    call CoreTime.dcoSync();
    call CTimer.startPeriodic(1024*60*60);       /* redo once per hour */
    signal Booted.booted();
  }


  event void CTimer.fired() {
    call CoreTime.dcoSync();
  }


  task void log_fault_task() {
    call OverWatch.checkFaults();
  }


  /*
   * start a dcoSync cycle
   * We use the underlying 32Ki XTAL to verify a reasonable setting of the DCO.
   */
  async command void CoreTime.dcoSync() {
    ct_rec_t *rec;

    atomic {
      /* ignore start if already busy */
      if (ct_state != CTS_IDLE)
        return;
      rec = get_core_rec();
      rec->arg = 0;
      ct_state = CTS_FIRST;
      ct_count = 5;
      RTC_C->PS1CTL = RTC_C_PS1CTL_RT1IP__128 | RTC_C_PS1CTL_RT1PSIE;
    }
  }


  void CS_Handler() @C() @spontaneous() __attribute__((interrupt)) {
    uint32_t cs_int;
    uint32_t cs_stat;

    cs_int  = CS->IFG;
    cs_stat = CS->STAT;
    if (cs_int & CS_IFG_LFXTIFG) {
      /*
       * 32Ki Xtal crapped out.
       */
      call OverWatch.setFault(OW_FAULT_32K);
      BITBAND_PERI(CS->IE, CS_IE_LFXTIE_OFS) = 0;
    }
    if (cs_int & CS_IFG_DCOR_SHTIFG) {
      /*
       * Short on external DCO resister, suspect that it causes
       * a reboot.  ie.  never here, suspected.
       */
      call OverWatch.setFault(OW_FAULT_DCOR);
    }
    if (cs_int & CS_IFG_DCOR_OPNIFG) {
      call OverWatch.setFault(OW_FAULT_DCOR);
      BITBAND_PERI(CS->IE, CS_IE_DCOR_OPNIE_OFS) = 0;
    }
    call Panic.panic(PANIC_TIME, 1, cs_int, cs_stat, 0, 0);
    post log_fault_task();
  }

  void RTC_Handler() @C() @spontaneous() __attribute__((interrupt)) {
    uint16_t  iv;
    ct_rec_t *rec;
    uint32_t  elapsed;

    iv = RTC_C->IV;
    switch(iv) {
      default:
      case 0: case 2:
      case 4: case 6:
      case 8: case 10:
        call Panic.panic(PANIC_TIME, 2, iv, 0, 0, 0);
        break;

      case 12:                          /* ps1 interrupt */
        switch(ct_state) {
          default:
          case CTS_IDLE:
            call Panic.panic(PANIC_TIME, 3, iv, ct_state, 0, 0);
            break;

          case CTS_FIRST:
            rec = get_core_rec();
            ct_last_usec = rec->usec;
            ct_state = CTS_CYCLE;
            break;

          case CTS_CYCLE:
            rec = get_core_rec();
            elapsed = rec->usec - ct_last_usec;
            ct_last_delta = USECS_TICKS - elapsed;
            ct_last_usec = rec->usec;
            rec->arg = ct_last_delta;
            if (--ct_count == 0) {
              ct_state = CTS_IDLE;
              RTC_C->PS1CTL = 0;        /* turn interrupt off */
            }
            break;
        }
    }
  }

  async event void Panic.hook() { }
}
