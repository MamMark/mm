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

/*
 * CoreTime handles low level issues dealing with time.
 *
 * - detection and graceful degradation of oscillator faults
 * - mclk/dco/aclk synchronization.  Xtal (32Ki LFXT) to Main Clk.
 * - deep sleep entry.  Enable timing recovery interrupt.
 * - deep sleep exit.   Timing system recovery.
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

norace uint16_t next_ta;
norace uint32_t ct_uis;
norace uint32_t ct_jifs;
norace uint32_t ct_start, ct_end;

norace uint32_t ct_cs_stat, ct_cs_exit_stat;

typedef enum {
  CT_IDLE = 0,
  CT_DSS_FIRST,                         /* first time can be weird */
  CT_DSS_SECOND,
  CT_DSS_CYCLE,
  CT_DEEP_SLEEP,                        /* deepsleep, normal            */
  CT_DEEP_FLIPPED,                      /* looking for edge, 7fff->8000 */
  CT_STATE_MAX,
} ct_state_t;                           /* coreTime state */


enum {
  CT_WHICH_NOT_SET  = -3,
  CT_WHICH_EDGE     = -2,
  CT_WHICH_OVERFLOW = -1,
};


/*
 * Core Time trace structure
 * used to record various Core Time events.
 * hybrid used by both dco sync as well as deep sleep
 *
 * 'a' says filled in by get_core_rec()
 */
typedef struct {
  uint32_t    usec;                     /* a usecsRaw() */
  uint32_t    ms;                       /* a localtime  */
  int32_t     last_delta;               /* - */
  uint16_t    ta_r;                     /* a */
  uint16_t    ps;                       /* a */
  uint16_t    target;                   /* a next stop */
  uint16_t    dest;                     /* a ultimate dest */

  rtctime_t   rtc;                      /* - rtc time, 18  */
  int8_t      which;                    /* a byte */
  ct_state_t  state;                    /* a byte */

  uint16_t    rtc_ps0ctl;
  uint16_t    rtc_ps1ctl;
  uint16_t    where;                    /* a */
#ifdef notdef
  uint32_t    nvic_enable[2];
  uint32_t    nvic_pending[2];
  uint32_t    nvic_active[2];
  uint32_t    xpsr;
  uint16_t    iv;
  uint16_t    rtc_ctl0;
  uint16_t    rtc_ctl13;
#endif
} ct_rec_t;

#define CT_ENTRIES 64
        ct_rec_t coretime_trace[CT_ENTRIES];
norace  uint32_t ct_nxt;


/* dco sync (ds) control block       */
/* main state is in ctcb, ctcb.state */
typedef struct {
  uint32_t   ds_last_usec;              /* last usec ticks */
  int32_t    ds_last_delta;             /* last delta off desired.  */
  int32_t    deltas[DS_CYCLE_COUNT];    /* entries from last cycle. */
  int32_t    adjustment;
  uint8_t    cycle_entry;               /* which entry are we working on */
  bool       collect_allowed;           /* collection is allowed.  */
} dscb_t;

norace dscb_t dscb;


/* coretime (ct) control block */
typedef struct {
  uint16_t   dest;                      /* final jiffy we are looing for   */
  uint16_t   target;                    /* the target we are going for     */
  uint32_t   delta_us;                  /* expected delta in uis/us        */
  uint16_t   delta_j;                   /* expected delta in jiffies       */
  uint16_t   iter;

  int8_t     which;                     /* deepsleep which target          */
  ct_state_t state;                     /* core time state                 */

  uint32_t   entry_ms;                  /* localtime entry to deep sleep   */
  uint32_t   entry_us;                  /* usecsRaw on entry to deep sleep */
  uint16_t   entry_ta;                  /* ta->R on entry to deep sleep    */

} ctcb_t;                               /* coretime control block          */

norace ctcb_t ctcb;


/*
 * debug core_time, acutally for dco sync
 * records last dco sync cycle start, first, end, and collect times.
 */
norace struct {
  rtctime_t start_time;
  rtctime_t first_time;
  rtctime_t end_time;
  rtctime_t collect_time;
} dbg_ct;


/*
 * debugging sleep.
 * record to record last sleep cycle.  entry and exit.
 */
typedef struct {
  rtctime_t   entry_rtc;                /* 18 bytes */
  uint16_t    entry_ta;                 /* ta->R on entry */
  uint32_t    entry_ms;                 /* localtime */
  uint32_t    entry_us;                 /* uis */

  rtctime_t   exit_rtc;
  uint16_t    exit_ta;                  /* ta->R on exit  */
  uint32_t    exit_ms;                  /* localtime */
  uint32_t    exit_us;                  /* uis */

  uint16_t    dest;                     /* dest    jiffies */
  uint16_t    target;                   /* target  jiffies */
  uint16_t    actual;                   /* actual  jiffies */
  uint16_t    delta_j;                  /* delta   jiffies */
  uint32_t    delta_us;                 /* delta   us      */

  uint16_t    where;
  ct_state_t  state;
} dbg_sleep_t;

#define MAX_SLEEP_ENTRIES 64
       dbg_sleep_t sleep_trace[MAX_SLEEP_ENTRIES];
norace uint32_t    sleep_nxt;


norace struct {
  uint32_t  entry_ms;
  uint32_t  entry_us;
  rtctime_t entry_rtc;
  uint16_t  entry_ta;

  uint32_t  exit_ms;
  uint32_t  exit_us;
  rtctime_t exit_rtc;
  uint16_t  exit_ta;
} dsi;                                  /* deep sleep instrumentation */


typedef struct {
  uint32_t ut0;
  uint16_t r;
  uint32_t ut1;
  uint16_t ps;
  uint32_t ut2;
  uint16_t where;
} dbg_r_ps_t;

#define DBG_R_PS_ENTRIES 64
        dbg_r_ps_t dbg_r_ps[DBG_R_PS_ENTRIES];
norace  uint32_t   dbg_r_ps_nxt;


typedef struct {
  uint32_t us;
  uint16_t rtc_ps0ctl;
  uint16_t rtc_ps1ctl;
  uint16_t ns;
  uint16_t mask;
  uint16_t ta;
  uint16_t ps;
  uint8_t  where;
} dbg_ps_int_t;


#define DBG_PS_INT_ENTRIES 64
        dbg_ps_int_t dbg_ps_int[DBG_PS_INT_ENTRIES];
norace  uint32_t     dbg_ps_int_nxt;


module CoreTimeP {
  provides {
    interface CoreTime;
    interface TimeSkew;
    interface Rtc  as CoreRtc;
    interface Boot as Booted;           /* Out boot */
    interface RtcHWInterrupt;           /* interrupt signaling */
  }
  uses {
    interface Boot;                     /* In Boot */
    interface Rtc;                      /* lower level interface */
    interface Collect;
    interface CollectEvent;
    interface OverWatch;
    interface McuSleep;
    interface Platform;
    interface Panic;
  }
}
implementation {

  uint16_t get_ps() {
    uint16_t ps0, ps1;

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
    return ps0;
  }


  ct_rec_t *get_core_rec(uint16_t where) {
    ct_rec_t *rec;

    atomic {
      rec = &coretime_trace[ct_nxt++];
      if (ct_nxt >= CT_ENTRIES)
        ct_nxt = 0;

      rec->ta_r   = call Platform.jiffiesRaw();
      rec->ps     = get_ps();

      rec->usec   = call Platform.usecsRaw();
      rec->ms     = call Platform.localTime();
      rec->target = ctcb.target;
      rec->dest   = ctcb.dest;
      rec->which  = ctcb.which;
      rec->state  = ctcb.state;
      rec->last_delta = -1;

      rec->rtc.year = -1;
      rec->where = where;
      rec->rtc_ps0ctl      = RTC_C->PS0CTL;
      rec->rtc_ps1ctl      = RTC_C->PS1CTL;
    }

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
#endif

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


  event void Collect.collectBooted() {
    dscb.collect_allowed = TRUE;
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
    if (dscb.collect_allowed)
      call CollectEvent.logEvent(DT_EVENT_DCO_REPORT,
            dscb.deltas[0], dscb.deltas[1],
            dscb.deltas[2], dscb.deltas[3]);
    abs_min = 0;
    for (i = 0; i < DS_CYCLE_COUNT; i++) {
      entry = dscb.deltas[i];
      if (entry < 0)            entry   = -entry;
      if (abs_min == 0)         abs_min = entry;
      else if (entry < abs_min) abs_min = entry;
    }
    n = 0;
    sum = 0;
    abs_min = abs_min + abs_min/2;
    for (i = 0; i < DS_CYCLE_COUNT; i++) {
      entry = dscb.deltas[i];
      if (entry < 0) entry = -entry;
      if (entry < abs_min) {
        sum += dscb.deltas[i];
        n++;
      }
    }
    entry = sum/n;
    dscb.adjustment = -entry/450;
    if (dscb.collect_allowed)
      call CollectEvent.logEvent(DT_EVENT_DCO_SYNC,
            dscb.adjustment, entry, sum, n);
    if (dscb.adjustment) {
      CS->KEY  = CS_KEY_VAL;
      control = CS->CTL0;
      dcotune = control & CS_CTL0_DCOTUNE_MASK;
      dcotune += dscb.adjustment;
      dcotune &= CS_CTL0_DCOTUNE_MASK;
      control = (control & ~CS_CTL0_DCOTUNE_MASK) | dcotune;
      CS->CTL0 = control;
      CS->KEY = 0;                  /* lock module */
      call CoreTime.dcoSync();
    }
    dscb.adjustment = 0;
    call CoreTime.verify();
  }


  /*
   * start a dcoSync cycle
   * We use the underlying 32Ki XTAL to verify a reasonable setting of the DCO.
   */
  command void CoreTime.dcoSync() {
    ct_rec_t *rec;

    atomic {
      /* ignore start if already busy */
      if (ctcb.state != CT_IDLE)
        return;

      rec = get_core_rec(1);
      rec->last_delta  = 0;
      ctcb.state = CT_DSS_FIRST;
      dscb.cycle_entry = 0;
      RTC_C->PS1CTL = RTC_C_PS1CTL_RT1IP__32 | RTC_C_PS1CTL_RT1PSIE;
      get_core_rec(2);
    }
  }


  /**
   * closeEnough(): check ta->R and PS for clososity
   */

  bool closeEnough(uint16_t ta, uint16_t ps) {
    if (ta == ps)                  return TRUE;
    if (ta == ((ps + 1) & 0x7fff)) return TRUE;
    if (((ta + 1) & 0x7fff) == ps) return TRUE;
    return FALSE;
  }


  /*
   * tweakPS(): set PS from current R with possible Q15 inversion.
   *
   * input:  inversion  0 for no inversion, 0x8000 to invert Q15.
   *         tap        pointer for returning last cur_ta read, TA->R
   *
   * return: bool       TRUE,  tweak took, inversion successful.
   *                    FALSE, SECS tweaked.  inversion not done.
   *
   * We are tweaking PS to either clear its normally inverted Q15 state or
   * we are tweaking PS to set the inverted Q15 state.  inverted with
   * respect to TA->R.
   *
   * When changing PS we have to stop the RTC but we want to do it in such
   * a way as to not cause any missed SECS transitions.  We do this by
   * handling 7fff/8000, ffff/0000 special.  (we are about to pop seconds).
   * If the inversion took, we return TRUE.
   *
   * If we are in danger of clocking the SECS register, ie. 7fff or ffff,
   * we spin for about 30.5 usecs to let the transition happen.  And return
   * FALSE.  This indicates to the caller that the inversion hasn't happened
   * and futher processing should be done.
   *
   * We always return the last value of TA->R read in *tap.
   */
  bool tweakPS(uint16_t inversion, uint16_t *tap) {
    uint16_t cur_ta, prev_ta;
    uint32_t t0, t1;
    uint16_t iter;

    prev_ta = call Platform.jiffiesRaw();
    /*
     * flip 0x8000 - 0xffff onto 0x0000 - 0x7fff
     * we are in danger of tweaking SECS if we are at 0x7fff.
     */
    if ((prev_ta & 0x7fff) < 0x7fff) { /* not in danger of tweaking seconds */
      /*
       * o open the lock
       * o jam TA->R ^ inversion (modified jiffiesRaw) into PS.
       * o PS/Q15 will either be flipped wrt R or not dependent on inversion.
       *
       * then recheck to make sure that R hasn't changed.  If it has rejam.
       * should be fine because it just ticked and we have 30.5 usecs to get it
       * right.
       *
       * o and close the lock.
       */
      RTC_C->CTL0 = (RTC_C->CTL0 & ~RTC_C_CTL0_KEY_MASK) | RTC_C_KEY;
      BITBAND_PERI(RTC_C->CTL13, RTC_C_CTL13_HOLD_OFS) = 1;
      RTC_C->PS   = prev_ta ^ inversion;
      cur_ta = call Platform.jiffiesRaw();
      if (cur_ta != prev_ta) {          /* oops */
        nop();                          /* BRK */
        RTC_C->PS = cur_ta ^ inversion; /* all better */
      }
      BITBAND_PERI(RTC_C->CTL13, RTC_C_CTL13_HOLD_OFS) = 0;
      BITBAND_PERI(RTC_C->CTL0,  RTC_C_CTL0_KEY_OFS)   = 0;
      *tap = cur_ta;
      return TRUE;
    }

    /*
     * we are at the 7fff boundary, 7fff or ffff.  Spin for upto 61 us waiting
     * for the jiffy to tick.  This lets the SEC tick to occur.
     */
    t0 = call Platform.usecsRaw();
    iter = 0;
    do {
      t1 = call Platform.usecsRaw();
      if ((t1 - t0) > 61)               /* shouldn't be longer than 30.5 */
        call Panic.panic(PANIC_TIME, 1, t0, t1, t1 - t0, 0);
      iter++;
      cur_ta = call Platform.jiffiesRaw();
    } while ((cur_ta & 0x7fff) != 0);
    ctcb.iter = iter;
    *tap = cur_ta;
    return FALSE;
  }


  /**
   * initDeepSleep: set up for deep sleep
   * Simple DeepSleep, switch main clocks to 32Ki.
   *
   * We simply switch the high speed clocks from the main clock
   * (16Mi) to a low speed clock (32Ki).  We have observed idle
   * current consumption drop from ~500 uA to ~150 uA.
   *
   * Note, if an interrupt occurs while we are checking various
   * conditions, this interrupt will cause the deepsleep to
   * be aborted.  This gets handled by the WFE.  Regular clocks
   * are restored via irq_preamble().
   *
   * It is assumed that this code is only called from McuSleep.sleep(),
   * and interrupts are blocked (atomic).
   */

  async command void CoreTime.initDeepSleep() {
    uint16_t cur_ta;

    /* if we are already doing something bail */
    if (ctcb.state != CT_IDLE)
      return;

    call CoreTime.log(16);

    cur_ta  = call Platform.jiffiesRaw();
    dsi.entry_ta = cur_ta;
    dsi.entry_us = call Platform.usecsRaw();
    dsi.entry_ms = call Platform.localTime();
    call Rtc.getTime(&dsi.entry_rtc);

    CS->KEY  = CS_KEY_VAL;
    CS->CTL1 = CS_CTL1_SELS__LFXTCLK | CS_CTL1_DIVS__2 | CS_CTL1_DIVHS__2 |
               CS_CTL1_SELA__LFXTCLK | CS_CTL1_DIVA__1 | 0 |
               CS_CTL1_SELM__LFXTCLK | CS_CTL1_DIVM__1;
    CS->KEY = 0;                        /* lock module */
    ct_cs_stat = CS->STAT;
    ctcb.state = CT_DEEP_SLEEP;
    return;
  }


  /**
   * irq_preamble(): interrupt entry.
   * called from interrupt handlers that can be invoked while in deep sleep.
   *
   * check if we are in deep sleep.
   *
   * Simple deep sleep, restore normal clocks.  deep sleep entry
   * tweaked main high speed clocks so we need to restore the original
   * high speed clocks.
   *
   * the usec ticker has been running at a degraded speed.  We need to
   * do a fix up, dependent on how long we have been asleep.  The RTC as
   * well as TA->R have been running normally (clocked by BCLK/ACLK which
   * is off the 32 Ki LFXT clock).
   */
  async command void CoreTime.irq_preamble() {
    dbg_sleep_t *sr;
    ct_rec_t    *cr;
    uint64_t     e_e, x_e;              /* entry/exit epoch */
    int32_t      d_s, d_u, d_j;         /* delta secs, micros, jifs */
    uint32_t     uis;
    uint32_t     tmp;

    Timer32_Type *tp;                   /* to play with T32 */

    ct_start = call Platform.usecsRaw();
    if (dsi.entry_rtc.year) {           /* are we in deep sleep? */
      if (ctcb.state < CT_DEEP_SLEEP || ctcb.state >= CT_STATE_MAX)
        call Panic.panic(PANIC_TIME, 1, ctcb.state, 0, 0, 0);

      /* first restart the clocks back up to correctness */
      CS->KEY  = CS_KEY_VAL;
      CS->CTL1 = CS_CTL1_SELS__DCOCLK  | CS_CTL1_DIVS__2 | CS_CTL1_DIVHS__2 |
                 CS_CTL1_SELA__LFXTCLK | CS_CTL1_DIVA__1 | 0 |
                 CS_CTL1_SELM__DCOCLK  | CS_CTL1_DIVM__1;
      CS->KEY = 0;                        /* lock module */
      ct_cs_stat = CS->STAT;

      /* capture old values of usecs and ta_r (sleeping) */
      cr = get_core_rec(32);              /* init and snag old times */

      dsi.exit_us = call Platform.usecsRaw();
      dsi.exit_ms = call Platform.localTime();
      dsi.exit_ta = cr->ta_r;
      call Rtc.getTime(&dsi.exit_rtc);
      dsi.entry_rtc.year = 0;
      ctcb.state = CT_IDLE;

      /* add rtc time stamp */
      call Rtc.copyTime(&cr->rtc, &dsi.exit_rtc);


      /* sleep debug record, finish any previous entry */
      sr = &sleep_trace[sleep_nxt++];   /* always advance to next. */
      if (sleep_nxt >= MAX_SLEEP_ENTRIES)
        sleep_nxt = 0;

      sr->where = 3;
      call Rtc.copyTime(&sr->exit_rtc, &dsi.exit_rtc);
      sr->exit_ta = dsi.exit_ta;
      sr->exit_ms = dsi.exit_ms;
      sr->exit_us = dsi.exit_us;

      nop();

      /* coming out of deep sleep.  Fix any timing elements */
      e_e = call Rtc.rtc2epoch(&dsi.entry_rtc);         /* entry epoch   */
      x_e = call Rtc.rtc2epoch(&dsi.exit_rtc);          /* exit  epoch   */
      d_s = (x_e >> 32) - (e_e >> 32);                  /* delta seconds */
      d_u = (x_e & 0xffffffff) - (e_e & 0xffffffff);    /* delta usecs   */
      d_j = dsi.exit_rtc.sub_sec - dsi.entry_rtc.sub_sec;
      if (d_u < 0) {                                    /* need to borrow */
        /*
         * if the micros need a borrow, so do the jifs.
         * micros is calculated from the sub_sec values and if micros need
         * a borrow so will the jifs.
         */
        d_s--;
        d_u += 1000000;                                 /* still decimal */
        d_j += 32768;
      }
      uis = d_u;                                        /* actual usecs  */
#ifdef USECS_BINARY
      uis =  (d_u * MSP432_T32_ONE_SEC) / 1000000;      /* convert to binary */
#endif
      uis += (d_s * MSP432_T32_ONE_SEC);

      ct_uis = uis;
      ct_jifs = d_j;
      sr->actual = d_j;
      cr->last_delta = d_j;

      /* Verify we are in a reasonable state, not too long, not too short */
      if (d_j != ctcb.delta_j) {
        /* probably needs a range check, ie. +1-3 ticks */
        call Panic.panic(PANIC_TIME, 1, d_j, ctcb.delta, 0, 0);
      }

      /*
       * fix T32_1, our usecs ticker
       * correct our uis value with h/w correction.  Takes about 4 uis to
       * stuff so isn't worth the bother.
       * subtract the result from the current usec ticker (its count down).
       * and stuff it back into the ticker.
       */
      tp = TIMER32_2;                   /* should be T32_1 */
      tmp = uis * MSP432_T32_USEC_DIV + 0;
      tmp = tp->VALUE - tmp;
      tp->LOAD = tmp;                   /* and restart ticker with new val */

      nop();
    }
  }


  void add_rps_log(uint16_t r, uint16_t ps, uint16_t where) {
    dbg_r_ps_t *rp;

    rp = &dbg_r_ps[dbg_r_ps_nxt++];
    if (dbg_r_ps_nxt >= DBG_R_PS_ENTRIES)
      dbg_r_ps_nxt = 0;

    rp->where = where;
    rp->ut0   = 0;
    rp->r     = r;
    rp->ut1   = 0;
    rp->ps    = ps;
    rp->ut2   = call Platform.usecsRaw();
  }


  /*
   * Verify that R and PS are relatively sync'd.  Originally we
   * subtracted and checked for delta of no more than 1.  But that
   * doesn't handle the special case of wrappage.  ie.  0x7fff/8000 and
   * 0xffff/0x0000, etc.
   */
  void check_r_ps(uint16_t r, uint16_t ps, uint16_t where) {
    if (closeEnough(r, ps)) return;
    atomic {
      add_rps_log(r, ps, where);
      call Panic.panic(PANIC_TIME, 2, r, ps,
                       call Platform.jiffiesRaw(), get_ps());
    }
  }


  async command void CoreTime.verify() {
    uint16_t cur_ta, cur_ps;

    atomic {
      cur_ta = call Platform.jiffiesRaw() & 0x7fff;
      cur_ps = get_ps() & 0x7fff;
      check_r_ps(cur_ta, cur_ps, 64);
    }
  }


  async command void CoreTime.log(uint16_t where) {
    dbg_r_ps_t *rp;
    uint16_t r, ps;

    rp = &dbg_r_ps[dbg_r_ps_nxt++];
    if (dbg_r_ps_nxt >= DBG_R_PS_ENTRIES)
      dbg_r_ps_nxt = 0;

    atomic {
      rp->where = where;
      rp->ut0 = call Platform.usecsRaw();
      r       = call Platform.jiffiesRaw();
      rp->ut1 = call Platform.usecsRaw();
      ps      = get_ps();
      rp->ut2 = call Platform.usecsRaw();
    }
    rp->r   = r;
    rp->ps  = ps;
    r  &= 0x7fff;
    ps &= 0x7fff;

    check_r_ps(r, ps, 65);
  }


  /**
   * CoreRtc: platform specific RTC routines.
   *
   * CoreRtc.syncSetTime() is the only routine actually different.  Other
   * routines are pass through.
   */
  async command void CoreRtc.rtcStop() {
    call Rtc.rtcStop();
  }

  async command void CoreRtc.rtcStart() {
    call Rtc.rtcStart();
  }

  async command bool CoreRtc.rtcValid(rtctime_t *time) {
    return call Rtc.rtcValid(time);
  }


  /**
   * CoreRtc.syncSetTime(): set RTC time.
   *
   * check for too much delta, if so reboot.
   * Keep PS Q15inverted wrt TA1->R.
   */
  command void CoreRtc.syncSetTime(rtctime_t *timep) {
    rtctime_t curtime;
    uint64_t  cur_e;                    /* cur epoch */
    uint32_t  cur_s;                    /* cur secs  */
    uint64_t  new_e;                    /* new epoch */
    uint32_t  new_s;                    /* new secs  */
    uint32_t  delta;                    /* difference */
    uint16_t  cur_ta;

    call Rtc.getTime(&curtime);
    cur_e = call Rtc.rtc2epoch(&curtime);
    cur_s = cur_e >> 32;

    new_e = call Rtc.rtc2epoch(timep);
    new_s = new_e >> 32;

    if (new_s > cur_s) delta = new_s - cur_s;
    else               delta = cur_s - new_s;

    call CollectEvent.logEvent(DT_EVENT_TIME_SKEW, cur_s, new_s, delta, 0);

    /*
     * for now we simply sync TA1->R to PS to avoid messing
     * with timers.  We always want the upper bit, Q15, inverted
     * in PS.  This will need to get fixed when we implement GPS time
     * which may change time when converging.
     *
     * Eventually, we can implement a skew algorithm that will gradually
     * advance or retard the timing gracefully.
     */
    timep->sub_sec = call Platform.jiffiesRaw() ^ 0x8000;
    call Rtc.setTime(timep);
    call CoreTime.log(19);
    if (!tweakPS(0x8000, &cur_ta))
      tweakPS(0x8000, &cur_ta);

    if (delta > 8)                      /* if bigger than 8 secs */
      call OverWatch.flush_boot(call OverWatch.getBootMode(),
                                ORR_TIME_SKEW);
  }


  async command void CoreRtc.setTime(rtctime_t *timep) {
    return call Rtc.setTime(timep);
  }


  async command void CoreRtc.getTime(rtctime_t *timep) {
    call Rtc.getTime(timep);
  }

  async command void CoreRtc.clearTime(rtctime_t *timep) {
    call Rtc.clearTime(timep);
  }

  async command void CoreRtc.copyTime(rtctime_t *dtimep, rtctime_t *stimep) {
    call Rtc.copyTime(dtimep, stimep);
  }

  async command int  CoreRtc.compareTimes(rtctime_t *time0p,
                                          rtctime_t *time1p) {
    return call Rtc.compareTimes(time0p, time1p);
  }

  async command uint64_t CoreRtc.rtc2epoch(rtctime_t *timep) {
    return call Rtc.rtc2epoch(timep);
  }

  async command uint32_t CoreRtc.subsec2micro(uint16_t jiffies) {
    return call Rtc.subsec2micro(jiffies);
  }

  async command uint16_t CoreRtc.micro2subsec(uint32_t micros) {
    return call Rtc.micro2subsec(micros);
  }


  void CS_Handler() @C() @spontaneous() __attribute__((interrupt)) {
    uint32_t cs_int;
    uint32_t cs_stat;

    call McuSleep.irq_preamble();
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
    ct_rec_t *rec;
    uint32_t  elapsed;

    iv = RTC_C->IV;
    switch(iv) {
      default:
      case 2:                           /* Osc Fault Int */
        call Panic.panic(PANIC_TIME, 4, iv, 0, 0, 0);
        break;

      case 0:                           /* no interrupt  */
        break;                          /* just ignore   */

      case 4:                           /* Rdy Int, secs */
        call McuSleep.irq_preamble();
        if ((RTC_C->CTL0 & RTC_C_CTL0_RDYIE) == 0)
          call Panic.panic(PANIC_TIME, 4, iv,
                           RTC_C_CTL0_RDYIE, RTC_C->CTL0, 0);
        signal RtcHWInterrupt.secInterrupt();
        return;

      case 6:                           /* Event Int */
        call McuSleep.irq_preamble();
        if ((RTC_C->CTL0 & RTC_C_CTL0_TEVIE) == 0)
          call Panic.panic(PANIC_TIME, 4, iv,
                           RTC_C_CTL0_TEVIE, RTC_C->CTL0, 0);
        signal RtcHWInterrupt.eventInterrupt();
        return;

      case 8:                           /* Alarm Int */
        call McuSleep.irq_preamble();
        if ((RTC_C->CTL0 & RTC_C_CTL0_AIE) == 0)
          call Panic.panic(PANIC_TIME, 4, iv,
                           RTC_C_CTL0_AIE, RTC_C->CTL0, 0);
        signal RtcHWInterrupt.alarmInterrupt();
        return;

      case 10:                          /* ps0 interrupt */
        call McuSleep.irq_preamble();
        break;

      case 12:                          /* ps1 interrupt */
        switch(ctcb.state) {
          default:
          case CT_IDLE:
            call Panic.panic(PANIC_TIME, 5, iv, ctcb.state, 0, 0);
            break;

          case CT_DSS_FIRST:
            rec = get_core_rec(3);
            dscb.ds_last_usec = rec->usec;
            ctcb.state = CT_DSS_SECOND;
            call Rtc.getTime(&dbg_ct.first_time);
            break;

          case CT_DSS_SECOND:
            rec = get_core_rec(4);
            dscb.ds_last_usec = rec->usec;
            ctcb.state = CT_DSS_CYCLE;
            call Rtc.getTime(&dbg_ct.first_time);
            break;

          case CT_DSS_CYCLE:
            rec = get_core_rec(5);
            elapsed = rec->usec - dscb.ds_last_usec;
            dscb.ds_last_delta = elapsed - USECS_TICKS/DS_INTERVAL;
            dscb.ds_last_usec  = rec->usec;
            rec->last_delta = dscb.ds_last_delta; /* neg: slow, pos: fast */
            dscb.deltas[dscb.cycle_entry] = rec->last_delta;
            dscb.cycle_entry++;
            if (dscb.cycle_entry >= DS_CYCLE_COUNT) {
              ctcb.state = CT_IDLE;
              call Rtc.getTime(&dbg_ct.end_time);
              RTC_C->PS1CTL = 0;                  /* turn interrupt off */
              post dco_sync_task();
            }
            break;

          case CT_DEEP_SLEEP:
          case CT_DEEP_FLIPPED:
            call McuSleep.irq_preamble();
            break;
        }
    }
  }


  /*************************************************************************
   *
   * low level functions are callable by startup routines.
   */

  void __rtc_rtcStart() @C() @spontaneous() {
    call Rtc.rtcStart();
  }

  void __rtc_setTime(rtctime_t *timep) @C() @spontaneous() {
    call Rtc.setTime(timep);
  }

  void __rtc_getTime(rtctime_t *timep) @C() @spontaneous() {
    call Rtc.getTime(timep);
  }

  bool __rtc_rtcValid(rtctime_t *timep) @C() @spontaneous() {
    return call Rtc.rtcValid(timep);
  }

  int __rtc_compareTimes(rtctime_t *time0p, rtctime_t *time1p) @C() @spontaneous() {
    return call Rtc.compareTimes(time0p, time1p);
  }

  default async event void TimeSkew.skew(int32_t skew) { }
  async event void Panic.hook() { }
}
