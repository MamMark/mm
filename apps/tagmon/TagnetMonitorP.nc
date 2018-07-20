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

uint32_t gt0, gt1;
uint16_t tt0, tt1;

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
   * Tagnet Monitor handles control of the radio to manage power
   * and balanced with presenting reasonable opportunities for
   * communication with a base station.
   *
   * Below are the enums and variables used to control hierarchical
   * state machine. See <tagmonograph.png> for specifics on the
   * state transitions.
   */

  // major states
  typedef enum {
    RS_NONE         = 0,
    RS_BASE         = 1,
    RS_HUNT         = 2,
    RS_LOST         = 3,
    RS_MAX,
  } radio_state_t;

  // minor states
  typedef enum {
    SS_NONE         = 0,
    SS_RECV_WAIT    = 1,
    SS_RECV         = 2,
    SS_STANDBY      = 3,
    SS_STANDBY_WAIT = 4,
    SS_MAX,
  } radio_substate_t;

  // context for a minor state (more than one)
  typedef struct {
    radio_substate_t  state;
    uint32_t          max_cycles;       // one per major
    uint32_t          timers[SS_MAX];   // per substate
  } radio_subgraph_t;

  // context for the major state
  typedef struct {
    radio_state_t     state;
    int32_t           cycle_cnt;        // one per system
    radio_subgraph_t  sub[RS_MAX];      // per state
  } radio_graph_t;

  // main radio controller data structure.
  //
  // Base: 2000/2000    ~2secs On/~2secs Off     4 sec cycle 50% duty
  // Hunt: 4000/26000   ~4secs On/~26secs Off   30 sec cycle 15% duty
  // Lost: 6000/6000000 ~6secs On/~600secs Off  10 min cycle  1% duty
  //
  // Hunt's 4 secs on is chosen to increase likelihood of catching tagfuse's
  // 1 sec retransmission windows.

  norace radio_graph_t  rcb = {
  //              cycle
  //  cur_state,    cnt
        RS_NONE,      0,

     //            cycle         RW   ON      OFF   SW
    {// substate   limit     N       RECV    STBY
      {  SS_NONE,     0,    {0,   0,    0,      0,   0 } },     /* none */
      {  SS_NONE,    -1,    {0, 1000,   50,     50, 1000 } },     /* base */
      {  SS_NONE,    -1,    {0, 1000, 4000,  26000, 1000 } },     /* hunt */
      {  SS_NONE,    -1,    {0, 1000, 9000, 900000, 1000 } },     /* lost */
    }
  };

  // instrumentation for radio state changes.

  typedef struct {
    uint32_t          count;
    uint32_t          ts_ms;
    uint32_t          ts_usecs;
    uint32_t          timeout;
    radio_state_t     major;
    radio_state_t     old_major;
    radio_substate_t  minor;
    radio_substate_t  old_minor;
  } radio_trace_t;

#define TAGMON_RADIO_TRACE_MAX 16

  radio_trace_t       radio_trace[TAGMON_RADIO_TRACE_MAX];
  norace uint32_t     radio_trace_cur;


  void change_radio_state(radio_state_t major, radio_substate_t minor) {
    error_t          error = SUCCESS;
    radio_state_t    old_major;
    radio_substate_t old_minor;
    radio_trace_t   *tt;
    uint32_t         tval;

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
    tval = rcb.sub[major].timers[minor]; // get timer from wait state

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
      tt->major = major; tt->old_major = old_major;
      tt->minor = minor; tt->old_minor = old_minor;
      tt->timeout = tval;
    } else {
      tt->count++;
      tt->ts_ms    = call Platform.localTime();
      tt->ts_usecs = call Platform.usecsRaw();
    }

    // start timer
    call smTimer.startOneShot(tval);

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
    change_radio_state(RS_BASE, SS_RECV);
  }

  command void TagnetMonitor.setHunt() {
    change_radio_state(RS_HUNT, SS_RECV);
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
    switch(minor) {
      case SS_RECV:
        change_radio_state(major, SS_STANDBY_WAIT);
        break;
      case SS_STANDBY:
        change_radio_state(major, SS_RECV_WAIT);
        break;
      default:
        call Panic.panic(PANIC_TAGNET, TAGNET_AUTOWHERE,
                         major, minor, 0, 0);
    }
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
     * transfer into MAJOR_BASE state.
     *
     * the change_radio_state handles the transition into BASE
     * and starting the BASE duty cycle timer.
     */
    change_radio_state(RS_BASE, SS_RECV);    // all go to base primary state
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
    major = rcb.state;
    minor = rcb.sub[major].state;
    switch (major) {
      case RS_BASE:     alt_major = RS_HUNT;    break;
      case RS_HUNT:     alt_major = RS_LOST;    break;
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


  event void smTimer.fired() {
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


  event void Boot.booted() {
    nop();                     /* BRK */
    change_radio_state(RS_BASE, SS_RECV_WAIT);
  }

  async event void Panic.hook() { }
}
