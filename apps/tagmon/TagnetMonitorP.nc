/*
 * Copyright (c) 2017-2018, Eric B. Decker, Daniel J. Maltbie
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

module TagnetMonitorP {
  provides interface TagnetMonitor;
  uses {
    interface Boot;
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
   *   HOME         tag is currently communicating with basestation
   *   NEAR         tag is going to switch radio to standby until clock event
   *   LOST         tag has not seen basestation and is in deep sleep
   */
  typedef enum {
    RS_NONE         = 0,
    RS_HOME         = 1,
    RS_NEAR         = 2,
    RS_LOST         = 3,
    RS_MAX,
  } radio_state_t;

  /*
   * minor states
   *   RECV         radio receiver is on
   *   RECV_WAIT    wait for radio_on command to complete
   *   STANDBY      radio in low power mode (register retained, recv off)
   *   STANDBY_WAIT waiting for radio_standby command to complete
   */
  typedef enum {
    SS_NONE         = 0,
    SS_RECV_WAIT    = 1,
    SS_RECV         = 2,
    SS_STANDBY_WAIT = 3,
    SS_STANDBY      = 4,
    SS_MAX,
  } radio_substate_t;

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
        RS_NONE,      0,

     //              max          R-W  RECV     S-W  STBY
    {// substate  cycles    NA
      {  SS_NONE,     0,    {0,    0,    0,      0,    0 } },    /* NA */
      {  SS_NONE,  2000,    {0, 1000,   50,   1000,   50 } },   /* home */
      {  SS_NONE,    40,    {0, 1000, 4000,   1000,   -1 } },   /* near */
      {  SS_NONE,    -1,    {0, 1000, 4000,   1000,   -5 } },   /* lost */
    }
  };

  // instrumentation for radio state changes
  typedef struct {
    uint32_t          count;
    uint32_t          cycles;
    uint32_t          ts_ms;
    uint32_t          ts_usecs;
    int32_t           timeout;
    radio_state_t     major;
    radio_state_t     old_major;
    radio_substate_t  minor;
    radio_substate_t  old_minor;
  } radio_trace_t;

#define TAGMON_RADIO_TRACE_MAX 16

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

  void change_radio_state(radio_state_t major, radio_substate_t minor) {
    error_t          error = SUCCESS;
    radio_state_t    old_major;
    radio_substate_t old_minor;
    radio_trace_t   *tt;
    int32_t          tval;
    rtctime_t        rt;

    nop();                     /* BRK */
    if (major == RS_NONE) {
      /* none says stay in current state. */
      major = rcb.state;
    }

    // check for range errors
    if ((major > sizeof(rcb.sub)/sizeof(rcb.sub[0])) ||
            (minor > sizeof(rcb.sub[0].timers)/sizeof(rcb.sub[0].timers[0])))
        call Panic.panic(PANIC_TAGNET, TAGNET_AUTOWHERE,
                         major, minor, 0, 0);

    // perform radio state change when appropriate substate is (re)entered
    // do this first because if it fails we will stay in the previous state
    // to try again
    switch(minor) {
      case SS_RECV_WAIT:
        error = call RadioState.turnOn();
        break;
      case SS_STANDBY_WAIT:
        error = call RadioState.standby();
        break;
      default:
        break;
    }
    // check for error, stay in same state if radio was busy,
    // this will cause wait timer to expire and retry the request
    if (error) {
      if (error == EBUSY) {
        major = rcb.state;
        minor = rcb.sub[major].state;
      }
      else
        call Panic.panic(PANIC_TAGNET, TAGNET_AUTOWHERE,
                         major, minor, error, 0);
    }
    // update state variables
    old_major = rcb.state;
    old_minor = rcb.sub[old_major].state;
    rcb.state = major;
    rcb.sub[major].state = minor;
    tval = rcb.sub[major].timers[minor]; // get timer for state

    // add info to trace array
    // only record the first instance of a repeated state change
    tt = &radio_trace[radio_trace_cur];
    if (tt->major     != major     || tt->minor     != minor ||
        tt->old_major != old_major || tt->old_minor != old_minor) {
      radio_trace_cur++;
      if (radio_trace_cur >= (sizeof(radio_trace)/sizeof(radio_trace[0])))
        radio_trace_cur = 0;
      tt = &radio_trace[radio_trace_cur];
      tt->ts_ms    = call Platform.localTime();
      tt->ts_usecs = call Platform.usecsRaw();
      tt->count    = 1;
      tt->cycles   = rcb.cycle_cnt;
      tt->major = major; tt->old_major = old_major;
      tt->minor = minor; tt->old_minor = old_minor;
      tt->timeout = tval;
    } else {
      tt->count++;
      tt->ts_ms    = call Platform.localTime();
      tt->ts_usecs = call Platform.usecsRaw();
    }

    // start timer or rtc alarm, depending on timout value
    if (tval < 0) {
      tval = 0 - tval;
      /* set rtc alarm to the next slice in 60 minute cycle
       *   slice = whole divisor of 60 minutes
       *   mps = minutes per slice
       *   rt.min = (((Rtc.getTime().min/mps) + 1) * mps) % 60
       *   RtcAlarm.set(rt, MIN)
       */
      call Rtc.getTime(&rt);
      if (is_divisorof60(tval)) {
        rt.min = (((rt.min / tval) + 1) * tval) % 60;
        call RtcAlarm.setAlarm(&rt, RTC_ALARM_MINUTE);
      } else
        call Panic.panic(PANIC_TAGNET, TAGNET_AUTOWHERE,
                         tval, rt.min, 0, 0);
    } else {
      call smTimer.startOneShot(tval);
    }

    // reset retry counter if changing major
    if (major != old_major)
      rcb.cycle_cnt = rcb.sub[major].max_cycles;

    nop();                              /* BRK */
  }

  void change_radio_state_cycle(radio_state_t major, radio_substate_t minor,
                                radio_state_t major_alt, radio_substate_t minor_alt) {
    // move to major,minor state when -1 or positive retry count
    switch (rcb.cycle_cnt) {
      case -1:  /* -1 says stay, good state machine */
        change_radio_state(major, minor);
        return;

      default:
        --rcb.cycle_cnt;
        if (rcb.cycle_cnt > 0) {
          /* more cycles to do, stay */
          change_radio_state(major, minor);
          return;
        }

        /* fall through if zero, ran out of cycles */
      case 0:
        /* ran out of cycles go to alternate */
        change_radio_state(major_alt, minor_alt);
        return;
    }
  }


  command void TagnetMonitor.setBase() {
    change_radio_state(RS_HOME, SS_RECV);
  }

  command void TagnetMonitor.setHunt() {
    change_radio_state(RS_NEAR, SS_RECV);
  }

  command void TagnetMonitor.setLost() {
    change_radio_state(RS_LOST, SS_RECV);
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

    nop();                     /* BRK */
    major = rcb.state;
    minor = rcb.sub[major].state;
    if (minor == SS_RECV) {
      change_radio_state(major, SS_STANDBY_WAIT);
      return;
    }
  }


  task void tagmon_forme_drop_task() {
    radio_state_t    major;
    radio_substate_t minor;

    major = rcb.state;
    minor = rcb.sub[major].state;
    if (minor == SS_RECV) {
      rcb.cycle_cnt = rcb.sub[RS_HOME].max_cycles;
      change_radio_state(RS_HOME, SS_RECV);    // all go to base primary state
      return;
    }
    call Panic.panic(PANIC_TAGNET, TAGNET_AUTOWHERE, major, minor, 0, 0);
  }


  task void tagmon_forme_task() {
    radio_state_t    major;
    radio_substate_t minor;
    error_t err;
    bool    rsp;

    nop();                     /* BRK */
    major = rcb.state;
    minor = rcb.sub[major].state;
    if (minor != SS_RECV) {
      /*
       * Not in RECV, but while we were we got a good one
       * FOR_ME.  Process it because it might do something
       * to us and needs to be done.  Only processing knows
       * for sure.
       *
       * But any response will go no where!.
       */
      call Tagnet.process_message(pTagMsg);
      tagMsgBusy = FALSE;
      return;
    }

    /*
     * we are in RECV.  And it is 'FOR_ME' in some fashion.
     * always take the 'FOR_ME' arc in the state machine and
     * transfer into MAJOR_HOME state.
     *
     * the change_radio_state handles the transition into BASE
     * and starting the BASE duty cycle timer.
     *
     * Also, reset the cycle counter since want to stay active
     * when the basestation is talking to this tag.
     */
    rcb.cycle_cnt = rcb.sub[RS_HOME].max_cycles;
    change_radio_state(RS_HOME, SS_RECV);    // all go to base primary state
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
      call Panic.panic(PANIC_TAGNET, TAGNET_AUTOWHERE, err, major, minor, 0);
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
      post tagmon_forme_drop_task();
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

    do {
      /*
       * first element of the msg is required to be
       * the dest node id.
       *
       * if no first element, or not a NODE_ID, punt.
       */
      this_tlv = call TName.first_element(msg);
      if ((!this_tlv) || (call TTLV.get_tlv_type(this_tlv) != TN_TLV_NODE_ID))
        break;

      /*
       * got a NODE_id, must be either our addr or the broadcast.
       */
      if (!call TTLV.eq_tlv(this_tlv,  TN_MY_NID_TLV)
          && !call TTLV.eq_tlv(this_tlv, (tagnet_tlv_t *)TN_BCAST_NID_TLV))
        break;

      /*
       * It is FOR_ME
       */
      return TRUE;
    } while (0);

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
    call smTimer.stop();
    major = rcb.state;
    minor = rcb.sub[major].state;
    switch (major) {
      case RS_HOME:     alt_major = RS_NEAR;    break;
      case RS_NEAR:     alt_major = RS_LOST;    break;
      default:          alt_major = RS_LOST;    break;
    }
    switch (minor) {
      case SS_RECV_WAIT:
        change_radio_state(major, SS_RECV);
        break;
      case SS_STANDBY_WAIT:
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


  task void timer_fired() {
    radio_state_t    major;
    radio_substate_t minor;

    nop();                     /* BRK */
    major = rcb.state;
    minor = rcb.sub[major].state;
    switch(minor) {
      case SS_RECV:
        /* ON timer expired, go to STBY, use OFF time */
        if (tagMsgBusy)  // defer change while processing msg
          change_radio_state(major, SS_RECV);
        else
          change_radio_state(major, SS_STANDBY_WAIT);
        break;
      case SS_STANDBY:
        /* OFF timer expired, go to RW and use ON time */
        change_radio_state(major, SS_RECV_WAIT);
        break;
      default:
        call Panic.panic(PANIC_TAGNET, TAGNET_AUTOWHERE,
                         major, minor, 0, 0);
    }
  }

  event void smTimer.fired() {
    post timer_fired();
  }

  async event void RtcAlarm.rtcAlarm(rtctime_t *timep,
                                     uint32_t field_set) {
    post timer_fired();
  }

  event void Boot.booted() {
    nop();                     /* BRK */
    change_radio_state(RS_HOME, SS_RECV_WAIT);
  }

  async event void Panic.hook() { }
}
