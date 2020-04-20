/*
 * Copyright (c) 2020, Eric B. Decker
 * Copyright (c) 2017-2019, Eric B. Decker, Daniel J. Maltbie
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
 *          Daniel J. Maltbie <dmaltbie@daloma.org>
 */

#include <Tasklet.h>
#include <tagnet_panic.h>
#include <rtc.h>
#include <rtctime.h>
#include <regime_ids.h>
#include <typed_data.h>

//noinit uint8_t use_regime;
uint8_t use_regime = RGM_DEFAULT;

module TagnetMonitorP {
  provides {
    interface TagnetRadio;
    interface McuPowerOverride;
  }
  uses {
    interface Boot;
    interface Regime;
    interface Tagnet;
    interface TagnetName as  TName;
    interface TagnetTLV  as  TTLV;
    interface Timer<TMilli> as smTimer;
    interface Random;
    interface RadioState;
    interface RadioSend;
    interface RadioReceive;
    interface Platform;
    interface Panic;
    interface Rtc;
    interface RtcAlarm;
    interface OverWatch;
    interface CollectEvent;
  }
}
implementation {
  /*
   * message buffer
   * Exchanged with radio driver every receive call.
   */
  norace volatile uint8_t     tagMsgBuffer[sizeof(message_t)] __attribute__ ((aligned (4)));
  norace message_t          * pTagMsg = (message_t *) tagMsgBuffer;
  norace          bool        tagMsgBusy;

  /*
   * Tagnet Monitor handles radio power management.
   *
   * The aim is to strike a balance between presenting reasonable
   * opportunities for communication with a base station while
   * minimizing power consumption.
   *
   * Below are the enums and variables used to control hierarchical
   * state machine. See <tagmonograph.png> for specifics on the
   * state transitions.
   */

  /*
   * major states
   *   SHUTDOWN     cpu has rebooted (initial ram state) or radio is shutdown
   *   HOME         tag is currently communicating with basestation
   *   NEAR         tag is going to switch radio to standby until clock event
   *   LOST         tag has not seen basestation and is in deep sleep
   */
  typedef enum {
    RS_SHUTDOWN     = 0,
    RS_HOME         = 1,
    RS_NEAR         = 2,
    RS_LOST         = 3,
    RS_MAX,
  } radio_state_t;

  /*
   * minor states
   *   RECV                radio receiver is on
   *   RECV_WAIT    (RW)   wait for radio_on command to complete
   *   STANDBY      (STBY) radio in low power mode (register retained, recv off)
   *   STANDBY_WAIT (SW)   waiting for radio_standby command to complete
   */
  typedef enum {
    SS_NONE         = 0,
    SS_RW           = 1,
    SS_RECV         = 2,
    SS_SW           = 3,
    SS_STANDBY      = 4,
    SS_MAX,
  } radio_substate_t;


  typedef enum {
    TMR_BOOT        = 0,
    TMR_FORCE       = 1,
    TMR_RSD         = 2,
    TMR_RSD_CYC     = 3,
    TMR_NOTME       = 4,
    TMR_FORME       = 5,
    TMR_DROP_BUSY   = 6,
    TMR_RTC         = 7,
    TMR_WINDOW      = 8,
    TMR_ALT         = 9,
    TMR_BUSY        = 10,
    TMR_FORME_NOTRECV = 11,
  } tagmon_reason_t;

  // context for a minor state (more than one)
  typedef struct {
    radio_substate_t  state;            // major state
    int32_t           max_cycles;       // one per major
    int32_t           timers[SS_MAX];   // per substate
  } radio_subgraph_t;

  // context for the major state
  typedef struct {
    radio_state_t     state;            // minor state
    int32_t           cycle_cnt;        // one per system
    radio_subgraph_t  sub[RS_MAX];      // per state
  } radio_graph_t;

  /*
   * Radio Controller Block data structure
   *
   * The RCB keeps track of states, retries, and timer values for the
   * monitor.
   *
   * This is a two level state machine, the top level (RS_) can be
   * one of the major states (HOME, NEAR, LOST). The second level (SS_)
   * controls the radio receive/standby cycle.
   *
   * A timer value is defined for each RS_/SS_ state pair. A positive
   * value specifies a time to wait in milliseconds. A negative value
   * specifies a time to wait based on wall clock, by minutes per slice.
   * A slice represents a precise whole integer number of minutes for
   * for a specific divisor of 60 minutes. This value is used to pick
   * the time the rtc alarm will fire (the next minute of the hour
   * based on current minute of the hour and minutes-per-slice).
   *
   * For the wall clock, the time to wait is specified by dividing the
   * hour by whole number divisors of 60 (1,2,3,4,5,6,10,12,15,20,30,60).
   *
   * Cycle count is used to control the number of cycles in the sub-state
   * machine to execute before transitioning to a different major-state.
   * A negative one (-1) value denotes to never leave. In addition to the
   * count being set on each major-state transition and being decremented
   * on each sub-state transition, it may also be modified on event
   * specific needs.
   */
  norace radio_graph_t  rcb = {
  //              cycle
  //  cur_state,    cnt
    RS_SHUTDOWN,      0,

     //              max          RW   RECV     SW   STBY
    {// substate  cycles    NA
      {  SS_NONE,     0,    {0,    0,    0,      0,    0 } },    /* NA */
      {  SS_NONE,  8000,    {0, 1024,   52,   1024,   52 } },   /* home */
      {  SS_NONE,   400,    {0, 1024, 4096,   1024,   -1 } },   /* near */
      {  SS_NONE,    -1,    {0, 1024, 4096,   1024,   -5 } },   /* lost */
    }
  };

  // instrumentation for radio state changes
  typedef struct {
    uint32_t          count;
    uint32_t          cycles;
    uint32_t          ts_ms;            /* start of transition time */
    uint32_t          ts_usecs;         /* start of transition time */
    uint32_t          ts_ms_last;       /* last seen for duplicates */
    uint32_t          ts_usecs_last;    /* last seen for duplicates */
    int32_t           timeout;
    radio_state_t     major;
    radio_substate_t  minor;
    radio_state_t     old_major;
    radio_substate_t  old_minor;
    tagmon_reason_t   reason;
  } radio_trace_t;

#define TAGMON_RADIO_TRACE_MAX 64

/* Trace Group is how far back in the trace to look for duplicates. */
#define TAGMON_TRACE_GROUP     4

  radio_trace_t       radio_trace[TAGMON_RADIO_TRACE_MAX];
  norace uint32_t     radio_trace_cur;

  // see if number is a whole divisor of 60 (for wall clock calc)
  bool is_divisorof60(int32_t val) {
    switch (val) {
      case 1:
      case 2:
      case 3:
      case 4:
      case 5:
      case 6:
      case 10:
      case 12:
      case 15:
      case 20:
      case 30:
      case 60:
        return TRUE;
      default:
        return FALSE;
    }
  }


  uint32_t get_index(int32_t delta) {
    int32_t idx;

    idx = radio_trace_cur + delta;
    if (idx >= TAGMON_RADIO_TRACE_MAX)
      idx -= TAGMON_RADIO_TRACE_MAX;
    if (idx < 0)
      idx = TAGMON_RADIO_TRACE_MAX + idx;
    return idx;
  }


  /*
   * add a standalone entry into the radio trace buffer.
   * It will use the current major/minor and the reason.
   *
   * It will add the entry in such way that it won't get folded into
   * previous states.
   */
  void add_radio_trace(tagmon_reason_t reason) {
    radio_state_t    major;
    radio_substate_t minor;
    uint32_t         event_ms, event_usecs;
    radio_trace_t   *tt;

    major       = rcb.state;
    minor       = rcb.sub[major].state;
    event_ms    = call Platform.localTime();
    event_usecs = call Platform.usecsRaw();

    radio_trace_cur = get_index(+1);
    tt = &radio_trace[radio_trace_cur];
    tt->count         = 0;
    tt->cycles        = 0;
    tt->ts_ms         = event_ms;
    tt->ts_usecs      = event_usecs;
    tt->ts_ms_last    = 0;
    tt->ts_usecs_last = 0;
    tt->timeout       = 0;
    tt->major         = major;
    tt->minor         = minor;
    tt->old_major     = RS_SHUTDOWN;
    tt->old_minor     = SS_NONE;
    tt->reason        = reason;
  }


  bool radio_transition_equal(radio_trace_t *t0, radio_trace_t *t1) {
    if (t0->major     == t1->major     && t0->minor     == t1->minor &&
        t0->old_major == t1->old_major && t0->old_minor == t1->old_minor &&
        t0->reason    == t1->reason)
      return TRUE;
    return FALSE;
  }


  void change_radio_state(radio_state_t major, radio_substate_t minor, tagmon_reason_t reason) {
    error_t          error = SUCCESS;
    radio_state_t    old_major;
    radio_substate_t old_minor;
    radio_trace_t   *tt;
    radio_trace_t    new_trace;
    int32_t          tval, i, j;
    rtctime_t        rt;
    bool             match;
    uint32_t         event_ms, event_usecs;

    // check for range errors
    if ((major > sizeof(rcb.sub)/sizeof(rcb.sub[0])) ||
            (minor > sizeof(rcb.sub[0].timers)/sizeof(rcb.sub[0].timers[0])))
        call Panic.panic(PANIC_TAGNET, TAGNET_AUTOWHERE,
                         major, minor, 0, 0);

    // capture the current time for the state transitions.  Do this before
    // we change the radio state so that the traces look right.
    event_ms    = call Platform.localTime();
    event_usecs = call Platform.usecsRaw();

    /*
     * Going into RW?  turn the radio on  (coming out of Standby).  Won't
     * be anything happening on the radio, its in Standby.  No race conditions
     * need apply.
     *
     * Going into SW?  turn the radio off (coming out of Recv), closing the
     * receive window.  This one is tricky...
     *
     * There is a race condition between the interrupt driven Radio state
     * machine and the synchronous Tagnet Monitor consumer.  We want to
     * stay in RECV as long as we are either receiving a packet or there
     * are unconsumed packets.  The first part is indicated by the Radio
     * State machine being busy (not RX_ON) and the later is indicated by
     * tagMsgBusy being TRUE.
     *
     * The race condition is from the time we look at tagMsgBusy to the
     * time we actually call the RadioState.standby().  During that time
     * a packet could complete (at interrupt) level, which causes tagMsgBusy
     * to go TRUE and for a consumption task to get posted.  If the transition
     * to Standby is allowed to happen this results in an illegal state.
     *
     * For now we prevent this by looking at tagMsgBusy and doing the transition
     * to standby within an atomic block.  The downside is we turn interrupts
     * off for approx 100us (while the standby processes) which isn't cool.
     */
    switch(minor) {
      case SS_NONE:
        error = call RadioState.standby();
        break;
      case SS_RW:
        error = call RadioState.turnOn();
        break;
      case SS_SW:
        atomic {
          if (tagMsgBusy)
            error = EBUSY;
          else
            error = call RadioState.standby();
        }
        break;
      default:
        break;
    }
    if (error) {
      if (error == EBUSY) {
        major = rcb.state;
        minor = rcb.sub[major].state;
        reason = TMR_BUSY;
      }
      else
        call Panic.panic(PANIC_TAGNET, TAGNET_AUTOWHERE,
                         major, minor, error, 0);
    }
    old_major = rcb.state;
    old_minor = rcb.sub[old_major].state;
    rcb.state = major;
    rcb.sub[major].state = minor;
    tval = rcb.sub[major].timers[minor]; // get timer for state

    /*
     * Add the state transition to the trace array.
     *
     * First, check for repeated last state.
     * If not a repeated last state then scan for duplicated
     * sequences.
     */
    tt = &radio_trace[radio_trace_cur];
    new_trace.major = major;
    new_trace.minor = minor;
    new_trace.old_major = old_major;
    new_trace.old_minor = old_minor;
    new_trace.reason    = reason;
    if (radio_transition_equal(tt, &new_trace)) {
      tt->count++;

      /* since this is a duplicate, only update the deltas */
      tt->ts_ms_last    = event_ms;
      tt->ts_usecs_last = event_usecs;
    } else {
      /*
       * actual transition, need to scan for same sequence
       * upto TAGMON_TRACE_GROUP (4).
       */
      radio_trace_cur = get_index(+1);
      tt = &radio_trace[radio_trace_cur];
      tt->ts_ms    = event_ms;
      tt->ts_usecs = event_usecs;
      tt->ts_ms_last    = 0;
      tt->ts_usecs_last = 0;
      tt->count    = 1;
      tt->cycles   = rcb.cycle_cnt;
      tt->major = major; tt->old_major = old_major;
      tt->minor = minor; tt->old_minor = old_minor;
      tt->timeout = tval;
      tt->reason = reason;

      /*
       * look for duplicate sequences (up to TRACE_GROUP back)
       * and collapse.
       *
       * We compare the following:
       *
       *      (2)         (3)         (4)
       *    0 vs -2     0 vs -3     0 vs -4
       *   -1    -3    -1    -4    -1    -5
       *               -2    -5    -2    -6
       *                           -3    -7
       *
       * if the column matches, then we fold the match into the
       * previous sequence.  ie.  both parts of (2) match so
       * we would fold 0 into -2 and -1 into -3.  Update lasts.
       */
      for (i = 2; i <= TAGMON_TRACE_GROUP; i++) {
        match = TRUE;
        for (j = 0; j < i; j++) {
          if (!radio_transition_equal(&radio_trace[get_index(-j)],
                                      &radio_trace[get_index(-j-i)])) {
            match = FALSE;
            break;
          }
        }
        if (match) break;
      }
      if (match) {
        /* i is the column we are working on. */
        for (j = 0; j < i; j++) {
          /*
           * we have a match.  For each folded entry we want to mark
           * the old sequence as not used (count goes to 0).
           *
           * Fold the duplicate into the original.  Pop the count and
           * update the {ms,usecs}_lasts.
           */
          tt = &radio_trace[get_index(-j)];     /* duplicate */
          tt->count = 0;
          event_ms    = tt->ts_ms;              /* latest event times */
          event_usecs = tt->ts_usecs;
          tt = &radio_trace[get_index(-j-i)];   /* original */
          tt->count++;
          tt->ts_ms_last    = event_ms;
          tt->ts_usecs_last = event_usecs;
        }
        radio_trace_cur = get_index(-i);        /* back cur up */
      }
    }

    /*
     * shutdown any timers/alarms dependent on old_minor.
     */
    if (old_minor == SS_SW || old_minor == SS_RW)
      call smTimer.stop();              /* kill deadman */
    if (old_minor == SS_STANDBY) {
      if (call RtcAlarm.getAlarm(NULL))
          call RtcAlarm.setAlarm(NULL, 0);
    }


    // start timer or rtc alarm, depending on timout value
    if (tval > 0)
      call smTimer.startOneShot(tval);
    if (tval < 0) {                     /* rtc interval */
      /*
       * neg value says use RtcAlarm.  Neg value denotes how
       * many slices to carve an hour into for the RtcAlarm.
       */
      tval = 0 - tval;

      /* set rtc alarm to the next slice in 60 minute cycle
       *   slice = whole divisor of 60 minutes
       *   mps = minutes per slice
       *   rt.min = (((Rtc.getTime().min/mps) + 1) * mps) % 60
       *   RtcAlarm.set(rt, MIN)
       */
      call Rtc.getTime(&rt);

      /* sanity check the slice value */
      if (!is_divisorof60(tval))
        call Panic.panic(PANIC_TAGNET, TAGNET_AUTOWHERE,
                         tval, rt.min, 0, 0);
      rt.min = (((rt.min / tval) + 1) * tval) % 60;
      call RtcAlarm.setAlarm(&rt, RTC_ALARM_MINUTE);
    }

    // reset retry counter if changing major
    if (major != old_major) {
      rcb.cycle_cnt = rcb.sub[major].max_cycles;

      /* and log major transitions */
      call CollectEvent.logEvent(DT_EVENT_RADIO_MODE, old_major,
                                 major, minor, reason);
    }
  }

  void change_radio_state_cycle(radio_state_t major, radio_substate_t minor,
                                radio_state_t major_alt, radio_substate_t minor_alt) {
    // move to major,minor state when -1 or positive retry count
    switch (rcb.cycle_cnt) {
      case -1:  /* -1 says stay, good state machine */
        change_radio_state(major, minor, TMR_RSD_CYC);
        return;

      default:
        --rcb.cycle_cnt;
        if (rcb.cycle_cnt > 0) {
          /* more cycles to do, stay */
          change_radio_state(major, minor, TMR_RSD_CYC);
          return;
        }

        /* fall through if zero, ran out of cycles */
      case 0:
        /* ran out of cycles go to alternate */
        change_radio_state(major_alt, minor_alt, TMR_ALT);
        return;
    }
  }


  command void TagnetRadio.setHome() {
    change_radio_state(RS_HOME, SS_RECV, TMR_FORCE);
  }

  command void TagnetRadio.setNear() {
    change_radio_state(RS_NEAR, SS_RECV, TMR_FORCE);
  }

  command void TagnetRadio.setLost() {
    change_radio_state(RS_LOST, SS_RECV, TMR_FORCE);
  }

  command void TagnetRadio.shutdown() {
    change_radio_state(RS_SHUTDOWN, SS_NONE, TMR_FORCE);
    tagMsgBusy = FALSE;
  }


  /*
   * NOT_FORME
   *
   * Handle state transitions when we have seen a packet
   * not FOR_ME.
   */
  task void tagmon_not_forme_task() {
    radio_state_t    major;
    radio_substate_t minor;

    major = rcb.state;
    minor = rcb.sub[major].state;
    if (minor == SS_RECV) {
      change_radio_state(major, SS_SW, TMR_NOTME);
      return;
    }
  }


  task void tagmon_forme_drop_busy_task() {
    radio_state_t    major;
    radio_substate_t minor;

    major = rcb.state;
    minor = rcb.sub[major].state;
    if (minor == SS_RECV) {
      rcb.cycle_cnt = rcb.sub[RS_HOME].max_cycles;
      change_radio_state(RS_HOME, SS_RECV, TMR_DROP_BUSY);
      return;
    }
  }


  task void tagmon_forme_task() {
    radio_state_t    major;
    radio_substate_t minor;
    error_t err;
    bool    rsp;

    major = rcb.state;
    minor = rcb.sub[major].state;
    if (minor != SS_RECV) {
      /*
       * We should never be here.  But there is a hole in the current
       * state machine that is caused by a race condition in buffer
       * handling between the interrupt driven radio state machine and
       * the synchronous TagnetMonitor consumer.  See change_radio_state.
       *
       * For now, just flag the mother and move on.  Ignore the msg, the
       * receive window has closed.
       */
      add_radio_trace(TMR_FORME_NOTRECV);
      call Panic.warn(PANIC_TAGNET, TAGNET_AUTOWHERE, major, minor, 0, 0);
      tagMsgBusy = FALSE;
      return;
    }

    /*
     * we are in RECV.  And it is 'FOR_ME' in some fashion.
     * always take the 'FOR_ME' arc in the state machine and
     * transfer into MAJOR_HOME state.
     *
     * the change_radio_state handles the transition into HOME
     * and starting the HOME duty cycle timer.
     *
     * Also, reset the cycle counter since want to stay active
     * when the basestation is talking to this tag.
     */
    rcb.cycle_cnt = rcb.sub[RS_HOME].max_cycles;
    change_radio_state(RS_HOME, SS_RECV, TMR_FORME);
    rsp = call Tagnet.process_message(pTagMsg);
    if (!rsp) {
      tagMsgBusy = FALSE;
      return;
    }

    /*
     * process message above indicated that we have a response
     * to send back.
     */
    err = call RadioSend.send(pTagMsg);
    if (err)
      call Panic.panic(PANIC_TAGNET, TAGNET_AUTOWHERE, major, minor, err, 0);
  }


  tasklet_async event void RadioSend.ready() { }


  tasklet_async event void RadioSend.sendDone(error_t error) {
    nop();
    if (!tagMsgBusy)
      call Panic.panic(PANIC_TAGNET, TAGNET_AUTOWHERE,
                       (parg_t) pTagMsg, 0, 0, 0);
    tagMsgBusy = FALSE;                 /* say this buffer available */
  }


  tasklet_async event message_t* RadioReceive.receive(message_t *msg) {
    message_t    * pNextMsg;

    nop();                     /* BRK */
    if (!msg)
      call Panic.panic(PANIC_TAGNET, TAGNET_AUTOWHERE, 0, 0, 0, 0);

    if (tagMsgBusy) {     // busy, ignore received msg by returning it
      /*
       * it was for us, but we can't handle it yet
       * post the drop task to stay awake
       */
      post tagmon_forme_drop_busy_task();
      return msg;
    }
    pNextMsg = pTagMsg;   // swap msg buffers, set busy, and post task
    pTagMsg = msg;
    tagMsgBusy = TRUE;
    post tagmon_forme_task();
    return pNextMsg;
  }


  tasklet_async event bool RadioReceive.header(message_t *msg) {
    tagnet_tlv_t    *this_tlv;

    nop();                              /* BRK */
    if (!msg)
      call Panic.panic(PANIC_TAGNET, TAGNET_AUTOWHERE,
                       0, 0, 0, 0);       /* null trap */

    /*
     * first element of the msg is required to be
     * the dest node id.
     *
     * if no first element, or not a NODE_ID, punt.
     */
    this_tlv = call TName.first_element(msg);
    if ((this_tlv && call TTLV.get_tlv_type(this_tlv) == TN_TLV_NODE_ID) &&
        (call TTLV.eq_tlv(this_tlv,  TN_MY_NID_TLV) ||
         call TTLV.eq_tlv(this_tlv, (tagnet_tlv_t *)TN_BCAST_NID_TLV)))
      return TRUE;

    /*
     * We don't want this packet NOT FOR_ME
     * tell the state machine, and punt the packet
     */
    post tagmon_not_forme_task();
    return FALSE;
  }


  task void radiostate_done_task() {
    radio_state_t    major, alt_major;
    radio_substate_t minor;

    nop();                     /* BRK */
    major = rcb.state;
    minor = rcb.sub[major].state;
    switch (major) {
      case RS_HOME:     alt_major = RS_NEAR;    break;
      case RS_NEAR:     alt_major = RS_LOST;    break;
      default:          alt_major = RS_LOST;    break;
    }
    switch (minor) {
      case SS_RW:
        change_radio_state(major, SS_RECV, TMR_RSD);
        break;
      case SS_SW:
        // stay in current major if cycles left, else go to next major
        change_radio_state_cycle(major, SS_STANDBY, alt_major, SS_STANDBY);
        break;
      default:
        call Panic.panic(PANIC_TAGNET, TAGNET_AUTOWHERE,
                         major, minor, 0, 0);
    }
  }


  async event void RadioState.done() {
    post radiostate_done_task();
  }


  void process_window_timer(tagmon_reason_t reason) {
    radio_state_t    major;
    radio_substate_t minor;

    major = rcb.state;
    minor = rcb.sub[major].state;
    switch(minor) {
      case SS_RECV:
        /* RECV window expired, go to STBY, use OFF time */
        change_radio_state(major, SS_SW, reason);
        break;
      case SS_STANDBY:
        /* OFF window expired, go to RW and use ON time */
        change_radio_state(major, SS_RW, reason);
        break;
      default:
        call Panic.panic(PANIC_TAGNET, TAGNET_AUTOWHERE, major, minor, 0, reason);
    }
  }

  event void smTimer.fired() {
    radio_state_t    major;
    radio_substate_t minor;

    major = rcb.state;
    minor = rcb.sub[major].state;
    if (minor == SS_SW || minor == SS_RW) {
      /*
       * deadman states cause panic.  shouldn't happen
       */
      call Panic.panic(PANIC_TAGNET, TAGNET_AUTOWHERE, major, minor, 0, 0);
    }
    process_window_timer(TMR_WINDOW);
  }

  task void rtcalarm_task() {
    radio_state_t    major;
    radio_substate_t minor;

    major = rcb.state;
    minor = rcb.sub[major].state;
    if (minor != SS_STANDBY)
      call Panic.panic(PANIC_TAGNET, TAGNET_AUTOWHERE, major, minor, 0, 0);
    process_window_timer(TMR_RTC);
  }

  async event void RtcAlarm.rtcAlarm(rtctime_t *timep, uint32_t field_set) {
    post rtcalarm_task();
  }

  /*
   * Tell McuSleep when we think it is okay to enter DEEPSLEEP.
   * For the Radio Monitor (TagMonitor), we think DEEPSLEEP is
   * just fine if we are using the RTCALARM for our next event.
   */
  async command mcu_power_t McuPowerOverride.lowestState() {
    if (rcb.state == RS_SHUTDOWN || call RtcAlarm.getAlarm(NULL)) {
      /*
       * If in RS_SHUTDOWN or we have an RtcAlarm set, then we are in a low
       * power wait tell McuSleep.
       */
      return POWER_DEEP_SLEEP;
    }
    return POWER_SLEEP;
  }

  event void Boot.booted() {
    /*
     * set the initial regime.  This will also
     * signal all the sensors and start them off.
     */
//    call Regime.setRegime(SNS_DEFAULT_REGIME);
    if (use_regime > RGM_MAX_REGIME)
      use_regime = RGM_DEFAULT;
    call Regime.setRegime(use_regime);

    if (call OverWatch.getDebugFlag(OW_DBG_NORDO)) {
      call RadioState.turnOff();
      return;
    }
    change_radio_state(RS_HOME, SS_RW, TMR_BOOT);
  }

  event void Regime.regimeChange() {} // do nothing.  that's okay.

  async event void Panic.hook() { }
}
