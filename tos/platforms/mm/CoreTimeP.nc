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

/*
 * CYCLE_COUNT: number of cycles (1 sec per interval) used in a reading
 * NUM_INTERVALS: number of intervals per sec.
 *
 * set PS1 interrupt to reflect NUM_INTERVALS.  ie.  2 -> IP__64 (2/sec)
 * and 1 -> IP__128 (1/sec).
 *
 * We do 4 cycles of 1/4 sec each cycle.  We should see
 * USECS_TICKS/DS_INTERVAL ticks in each cycle.  We have observed
 *
 */
#define DS_CYCLE_COUNT 4
#define DS_INTERVAL    4

typedef enum {
  DSS_IDLE = 0,
  DSS_FIRST,                            /* first time can be weird */
  DSS_SECOND,
  DSS_CYCLE,
} ds_minor_t;                           /* dcoSync minor state */


typedef struct {
  uint32_t    usec;
  int32_t     last_delta;
  uint16_t    ta_r;
  uint16_t    ps;
  ds_minor_t  minor;
#ifdef notdef
  uint32_t    nvic_enable[2];
  uint32_t    nvic_pending[2];
  uint32_t    nvic_active[2];
  uint32_t    xpsr;
  uint16_t    iv;
  uint16_t    rtc_ctl0;
  uint16_t    rtc_ctl13;
  uint16_t    rtc_ps0ctl;
  uint16_t    rtc_ps1ctl;
#endif
} ds_rec_t;

typedef struct {
  uint32_t   cycle_entry;               /* which entry are we working on */
  uint32_t   ds_last_usec;              /* last usec ticks */
  int32_t    ds_last_delta;             /* last delta off desired.  */
  int32_t    deltas[DS_CYCLE_COUNT];    /* entries from last cycle. */
  int32_t    adjustment;
  ds_minor_t minor_state;
  bool       collect_allowed;           /* collection is allowed.  */
} ctcb_t;                               /* coretime control block  */

#define DS_ENTRIES 32
        ds_rec_t dcosync_trace[DS_ENTRIES];
norace  uint32_t ds_nxt;

ctcb_t ctcb;

struct {
  rtctime_t start_time;
  rtctime_t first_time;
  rtctime_t end_time;
  rtctime_t collect_time;
} dbg_ct;


module CoreTimeP {
  provides {
    interface CoreTime;
    interface Boot as Booted;           /* Out boot */
    interface RtcHWInterrupt;           /* interrupt signaling */
  }
  uses {
    interface Boot;                     /* In Boot */
    interface Timer<TMilli> as DSTimer;
    interface Rtc;
    interface Collect;
    interface CollectEvent;
    interface OverWatch;
    interface Platform;
    interface Panic;
  }
}
implementation {
  ds_rec_t *get_core_rec() {
    ds_rec_t *rec;
    uint16_t ps0, ps1;

    rec = &dcosync_trace[ds_nxt++];
    if (ds_nxt >= DS_ENTRIES)
      ds_nxt = 0;
    rec->usec = call Platform.usecsRaw();
    rec->ta_r = call Platform.jiffiesRaw();
    rec->minor = ctcb.minor_state;

#ifdef notdef
    rec->nvic_enable[0]  = NVIC->ISER[0];
    rec->nvic_enable[1]  = NVIC->ISER[1];
    rec->nvic_pending[0] = NVIC->ISPR[0];
    rec->nvic_pending[1] = NVIC->ISPR[1];
    rec->nvic_active[0]  = NVIC->IABR[0];
    rec->nvic_active[1]  = NVIC->IABR[1];
    rec->xpsr            = __get_xPSR();
    rec->iv = -1;
    rec->rtc_ctl0        = RTC_C->CTL0;
    rec->rtc_ctl13       = RTC_C->CTL13;
    rec->rtc_ps0ctl      = RTC_C->PS0CTL;
    rec->rtc_ps1ctl      = RTC_C->PS1CTL;
#endif

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
      call OverWatch.sysBootStart();    /* tell overwatch, sysboot start */
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
    call Rtc.getTime(&dbg_ct.start_time);
    call CoreTime.dcoSync();
    signal Booted.booted();
  }

  event void DSTimer.fired() {
    switch(ctcb.minor_state) {
      default:
        call Panic.panic(PANIC_TIME, 1, 0, 0, 0, 0);
        return;

      case DSS_IDLE:
        call CoreTime.dcoSync();
        return;
    }
  }


  event void Collect.collectBooted() {
    ctcb.collect_allowed = TRUE;
    call Rtc.getTime(&dbg_ct.collect_time);
  }


  task void log_fault_task() {
    call OverWatch.checkFaults();
  }

  /*
   * process the data collected in a dcoSync cycle.
   *
   * looking for various things.
   * if we see a zero crossing, ignore the whole cycle.
   * look for the minimum.
   * ignore any entries that are bigger than 1.5 * min.
   *
   * our steps seem to be about 400 units.
   */
  task void dco_sync_task() {
    int i, n, abs_min, sum, entry;
    uint32_t control, dcotune;

    /* check for end happening too fast */
    if (ctcb.collect_allowed)
      call CollectEvent.logEvent(DT_EVENT_DCO_REPORT,
            ctcb.deltas[0], ctcb.deltas[1],
            ctcb.deltas[2], ctcb.deltas[3]);
    abs_min = 0;
    for (i = 0; i < DS_CYCLE_COUNT; i++) {
      entry = ctcb.deltas[i];
      if (entry < 0)            entry   = -entry;
      if (abs_min == 0)         abs_min = entry;
      else if (entry < abs_min) abs_min = entry;
    }
    n = 0;
    sum = 0;
    abs_min = abs_min + abs_min/2;
    for (i = 0; i < DS_CYCLE_COUNT; i++) {
      entry = ctcb.deltas[i];
      if (entry < 0) entry = -entry;
      if (entry < abs_min) {
        sum += ctcb.deltas[i];
        n++;
      }
    }
    entry = sum/n;
    ctcb.adjustment = -entry/450;
    if (ctcb.collect_allowed)
      call CollectEvent.logEvent(DT_EVENT_DCO_SYNC,
            ctcb.adjustment, entry, sum, n);
    if (ctcb.adjustment) {
      CS->KEY  = CS_KEY_VAL;
      control = CS->CTL0;
      dcotune = control & CS_CTL0_DCOTUNE_MASK;
      dcotune += ctcb.adjustment;
      dcotune &= CS_CTL0_DCOTUNE_MASK;
      control = (control & ~CS_CTL0_DCOTUNE_MASK) | dcotune;
      CS->CTL0 = control;
      CS->KEY = 0;                  /* lock module */
      call CoreTime.dcoSync();
    }
    nop();
    ctcb.adjustment = 0;
  }


  /*
   * start a dcoSync cycle
   * We use the underlying 32Ki XTAL to verify a reasonable setting of the DCO.
   */
  command void CoreTime.dcoSync() {
    ds_rec_t *rec;

    atomic {
      /* ignore start if already busy */
      if (ctcb.minor_state != DSS_IDLE)
        return;
      rec = get_core_rec();
      rec->last_delta  = 0;
      ctcb.minor_state = DSS_FIRST;
      ctcb.cycle_entry = 0;
      RTC_C->PS1CTL = RTC_C_PS1CTL_RT1IP__32 | RTC_C_PS1CTL_RT1PSIE;
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
    call Panic.panic(PANIC_TIME, 3, cs_int, cs_stat, 0, 0);
    post log_fault_task();
  }


  void RTC_Handler() @C() @spontaneous() __attribute__((interrupt)) {
    uint16_t  iv;
    ds_rec_t *rec;
    uint32_t  elapsed;

    iv = RTC_C->IV;
    switch(iv) {
      default:
      case 2:
      case 10:
        call Panic.panic(PANIC_TIME, 4, iv, 0, 0, 0);
        break;

      case 0:                           /* no interrupt  */
        break;                          /* just ignore   */

      case 4:
        if ((RTC_C->CTL0 & RTC_C_CTL0_RDYIE) == 0)
          call Panic.panic(PANIC_TIME, 4, iv,
                           RTC_C_CTL0_RDYIE, RTC_C->CTL0, 0);
        signal RtcHWInterrupt.secInterrupt();
        return;

      case 6:
        if ((RTC_C->CTL0 & RTC_C_CTL0_TEVIE) == 0)
          call Panic.panic(PANIC_TIME, 4, iv,
                           RTC_C_CTL0_TEVIE, RTC_C->CTL0, 0);
        signal RtcHWInterrupt.eventInterrupt();
        return;

      case 8:
        if ((RTC_C->CTL0 & RTC_C_CTL0_AIE) == 0)
          call Panic.panic(PANIC_TIME, 4, iv,
                           RTC_C_CTL0_AIE, RTC_C->CTL0, 0);
        signal RtcHWInterrupt.alarmInterrupt();
        return;

      case 12:                          /* ps1 interrupt */
        switch(ctcb.minor_state) {
          default:
          case DSS_IDLE:
            call Panic.panic(PANIC_TIME, 5, iv, ctcb.minor_state, 0, 0);
            break;

          case DSS_FIRST:
            rec = get_core_rec();
            ctcb.ds_last_usec = rec->usec;
            ctcb.minor_state = DSS_SECOND;
            call Rtc.getTime(&dbg_ct.first_time);
            break;

          case DSS_SECOND:
            rec = get_core_rec();
            ctcb.ds_last_usec = rec->usec;
            ctcb.minor_state = DSS_CYCLE;
            call Rtc.getTime(&dbg_ct.first_time);
            break;

          case DSS_CYCLE:
            rec = get_core_rec();
            elapsed = rec->usec - ctcb.ds_last_usec;
            ctcb.ds_last_delta = elapsed - USECS_TICKS/DS_INTERVAL;
            ctcb.ds_last_usec  = rec->usec;
            rec->last_delta = ctcb.ds_last_delta; /* neg: slow, pos: fast */
            ctcb.deltas[ctcb.cycle_entry] = rec->last_delta;
            ctcb.cycle_entry++;
            if (ctcb.cycle_entry >= DS_CYCLE_COUNT) {
              ctcb.minor_state = DSS_IDLE;
              call Rtc.getTime(&dbg_ct.end_time);
              RTC_C->PS1CTL = 0;                  /* turn interrupt off */
              post dco_sync_task();
            }
            break;
        }
    }
  }

  event void Collect.resyncDone(error_t err, uint32_t offset) { }

  async event void Panic.hook() { }
}
