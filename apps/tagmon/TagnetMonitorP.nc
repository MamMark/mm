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
  uses {
    interface Boot;
    interface TagnetName;
    interface TagnetPayload;
    interface TagnetTLV;
    interface TagnetHeader;
    interface Tagnet;
    interface Timer<TMilli> as rcTimer;
    interface Timer<TMilli> as txTimer;
    interface Panic;
    interface Random;
    interface RadioState;
    interface RadioSend;
    interface RadioReceive;
  }
}
implementation {
  /*
   * message buffer
   *
   * Exchanged with radio driver every receive call.
   */
  norace volatile uint8_t     tagMsgBuffer[sizeof(message_t)] __attribute__ ((aligned (4)));
  norace volatile uint8_t     tagMsgBufferGuard[] = "DEADBEAF";
  norace message_t          * pTagMsg = (message_t *) tagMsgBuffer;
  norace          uint8_t     tagMsgBusy, tagMsgSending;
                  uint32_t    tagmon_timeout  = 20; // milliseconds

  /*
   * radio state info
   */
  typedef enum {
    RS_NONE         = 0,
    RS_BASE         = 1,
    RS_HUNT         = 2,
    RS_LOST         = 3,
    RS_MAX,
  } radio_state_t;

  typedef enum {
    SS_NONE         = 0,
    SS_RECV         = 1,
    SS_STANDBY      = 2,
    SS_RECV_WAIT    = 3,
    SS_STANDBY_WAIT = 4,
    SS_MAX,
  } radio_substate_t;

  typedef struct {
    radio_substate_t  state;
    uint32_t          max_retries;
    uint32_t          timers[SS_MAX];
  } radio_subgraph_t;

  typedef struct {
    radio_state_t     state;
    int32_t           retry_counter;
    radio_subgraph_t  sub[RS_MAX];
  } radio_graph_t;

  typedef struct {
    radio_state_t     major;
    radio_state_t     old_major;
    radio_substate_t  minor;
    radio_substate_t  old_minor;
    uint32_t          timeout;
  } radio_trace_t;

  radio_trace_t       radio_trace[10];
  norace uint32_t     radio_trace_head;

  norace radio_graph_t  rcb = {
    RS_NONE, 5,
    {{SS_NONE, 0, {0,    0,      0,   0,   0}},
     {SS_NONE, 5, {0, 3000,  15000, 100, 100}},
     {SS_NONE, 5, {0, 6000,  60000, 100, 100}},
     {SS_NONE, 5, {0, 2000, 300000, 100, 100}}},
  };

  /*
   * {state = TagnetMonitorP__RS_BASE, retry_counter = 0x4,
   *    sub =
   *    { {state = TagnetMonitorP__SS_NONE, max_retries = 0x0, timers = {0x0, 0x0, 0x0}},
   *      {state = TagnetMonitorP__SS_STANDBY, max_retries = 0x5, timers = {0x0, 0xbb8, 0x3a98}},
   *      {state = TagnetMonitorP__SS_NONE, max_retries = 0x5, timers = {0x0, 0x1770, 0xea60}},
   *      {state = TagnetMonitorP__SS_NONE, max_retries = 0x5, timers = {0x0, 0x7d0, 0x493e0}}
   *    }
   * }
  */

  void change_radio_state(radio_state_t major, radio_substate_t minor) {
    error_t          error = SUCCESS;
    radio_state_t    old_major;
    radio_substate_t old_minor;
    radio_trace_t   *tt;

    nop();
    nop();                     /* BRK */
    if (major == RS_NONE) major = rcb.state;
    if ((major > sizeof(rcb.sub)/sizeof(rcb.sub[0])) ||
        (minor > sizeof(rcb.sub[0].timers)/sizeof(rcb.sub[0].timers[0])))
        call Panic.panic(PANIC_TAGNET, TAGNET_AUTOWHERE,
                         major, minor, 0, 0);
    old_major = rcb.state;
    old_minor = rcb.sub[major].state;
    rcb.state = major;
    rcb.sub[major].state = minor;
    if (radio_trace_head >= (sizeof(radio_trace)/sizeof(radio_trace[0])))
      radio_trace_head = 0;
    tt = &radio_trace[radio_trace_head++];
    tt->major = major; tt->old_major = old_major;
    tt->minor = minor; tt->old_minor = old_minor;
    tt->timeout = rcb.sub[major].timers[minor];
    call txTimer.startOneShot(rcb.sub[major].timers[minor]);
    if (major != old_major)
      rcb.retry_counter = rcb.sub[major].max_retries;
    if (old_minor != minor) {
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
      if (error)
        call Panic.panic(PANIC_TAGNET, TAGNET_AUTOWHERE,
                         major, minor, (uint32_t) error, 0);
    }
  }

  task void network_task() {
    nop();
    nop();                     /* BRK */
    if (call Tagnet.process_message(pTagMsg)) {
      /*
       * if the message processor returns TRUE that says the message now contains
       * the outgoing response.  Fire the turn around timer which kicks the
       * sender.
       *
       * Don't mark the current msg buffer until the sender finishes.
       */
      nop();                     /* BRK */
      if (rcb.sub[rcb.state].state == SS_RECV) { // should only be in recv state
        call rcTimer.startOneShot(tagmon_timeout); /* fire up turn around timer */
        change_radio_state(RS_BASE, SS_RECV);    // all got to base primary state
        return;
      }
      call Panic.panic(PANIC_TAGNET, TAGNET_AUTOWHERE,
                       rcb.state, rcb.sub[rcb.state].state, 0, 0);
    }

    /*
     * The message processor says no return message just mark the buffer as
     * available and be done with it.
     */
    nop();                     /* BRK */
    if (rcb.sub[rcb.state].state == SS_RECV) { // should only be in recv state
      tagMsgBusy = FALSE;
      change_radio_state(rcb.state, SS_STANDBY_WAIT);
      return;
    }
    call Panic.panic(PANIC_TAGNET, TAGNET_AUTOWHERE,
                     rcb.state, rcb.sub[rcb.state].state, 0, 0);
  }

  tasklet_async event void RadioSend.ready() {
    nop();
  }

  tasklet_async event void RadioSend.sendDone(error_t error) {
    nop();
    if (!tagMsgBusy)
      call Panic.panic(PANIC_TAGNET, TAGNET_AUTOWHERE,
                       (parg_t) pTagMsg, 0, 0, 0);

    tagMsgSending = FALSE;              /* informational state */
    tagMsgBusy    = FALSE;              /* say this buffer available */
  }

  tasklet_async event message_t* RadioReceive.receive(message_t *msg) {
    message_t    * pNextMsg;
    nop();
    nop();                     /* BRK */
    if (!msg)
      call Panic.panic(PANIC_TAGNET, TAGNET_AUTOWHERE, 0, 0, 0, 0);

    if (tagMsgBusy) {     // busy, ignore received msg by returning it
      return msg;
    }
    pNextMsg = pTagMsg;   // swap msg buffers, set busy, and post task
    pTagMsg = msg;
    tagMsgBusy = TRUE;
    post network_task();
    return pNextMsg;
  }

  tasklet_async event bool RadioReceive.header(message_t *msg) {
    nop();
    return TRUE;
  }

  async event void RadioState.done() {
    nop();
    nop();                     /* BRK */
    switch (rcb.state) {
      case RS_BASE:
        switch (rcb.sub[rcb.state].state) {
          case SS_RECV_WAIT:
            change_radio_state(RS_BASE, SS_RECV);
            break;
          case SS_STANDBY_WAIT:
            if (--rcb.retry_counter <= 0)
              change_radio_state(RS_HUNT, SS_STANDBY);
            else
              change_radio_state(RS_BASE, SS_STANDBY);
            break;
          default:
            call Panic.panic(PANIC_TAGNET, TAGNET_AUTOWHERE,
                             rcb.state, rcb.sub[rcb.state].state, 0, 0);
        }
        break;
      case RS_HUNT:
        switch (rcb.sub[rcb.state].state) {
          case SS_RECV_WAIT:
            change_radio_state(RS_HUNT, SS_RECV);
            break;
          case SS_STANDBY_WAIT:
            if (--rcb.retry_counter <= 0)
              change_radio_state(RS_LOST, SS_STANDBY);
            else
              change_radio_state(RS_HUNT, SS_STANDBY);
            break;
          default:
            call Panic.panic(PANIC_TAGNET, TAGNET_AUTOWHERE,
                             rcb.state, rcb.sub[rcb.state].state, 0, 0);
        }
        break;
      case RS_LOST:
        switch (rcb.sub[rcb.state].state) {
          case SS_RECV_WAIT:
            change_radio_state(RS_LOST, SS_RECV);
            break;
          case SS_STANDBY_WAIT:
            change_radio_state(RS_LOST, SS_STANDBY);
            break;
          default:
            call Panic.panic(PANIC_TAGNET, TAGNET_AUTOWHERE,
                             rcb.state, rcb.sub[rcb.state].state, 0, 0);
        }
        break;
      default:
        call Panic.panic(PANIC_TAGNET, TAGNET_AUTOWHERE,
                         rcb.state, rcb.sub[rcb.state].state, 0, 0);
        break;
    }
  }


  event void rcTimer.fired() {
    error_t err;
    nop();
    nop();                     /* BRK */
    tagMsgSending = TRUE;
    err = call RadioSend.send(pTagMsg);
    switch (err) {
      case SUCCESS:
        break;
      case EBUSY: // collided with a receive
        tagMsgSending = FALSE;
        tagMsgBusy    = FALSE;
        break;
      default:
        call Panic.panic(PANIC_TAGNET, TAGNET_AUTOWHERE, err, 0, 0, 0);
    }
  }


  event void txTimer.fired() {
    nop();
    nop();                     /* BRK */
    switch (rcb.state) {
      case RS_BASE:
        switch (rcb.sub[rcb.state].state) {
          case SS_RECV:
            change_radio_state(RS_BASE, SS_STANDBY_WAIT);
            break;
          case SS_STANDBY:
            change_radio_state(RS_BASE, SS_RECV_WAIT);
            break;
          default:
            call Panic.panic(PANIC_TAGNET, TAGNET_AUTOWHERE,
                             rcb.state, rcb.sub[rcb.state].state, 0, 0);
        }
        break;
      case RS_HUNT:
        switch (rcb.sub[rcb.state].state) {
          case SS_RECV:
            change_radio_state(RS_HUNT, SS_STANDBY_WAIT);
            break;
          case SS_STANDBY:
            change_radio_state(RS_HUNT, SS_RECV_WAIT);
            break;
          default:
            call Panic.panic(PANIC_TAGNET, TAGNET_AUTOWHERE,
                             rcb.state, rcb.sub[rcb.state].state, 0, 0);
        }
        break;
      case RS_LOST:
        switch (rcb.sub[rcb.state].state) {
          case SS_RECV:
            change_radio_state(RS_LOST, SS_STANDBY_WAIT);
            break;
          case SS_STANDBY:
            change_radio_state(RS_LOST, SS_RECV_WAIT);
            break;
          default:
            call Panic.panic(PANIC_TAGNET, TAGNET_AUTOWHERE,
                             rcb.state, rcb.sub[rcb.state].state, 0, 0);
        }
        break;
      default:
        call Panic.panic(PANIC_TAGNET, TAGNET_AUTOWHERE,
                         rcb.state, rcb.sub[rcb.state].state, 0, 0);
    }
  }


  event void Boot.booted() {
    nop();                     /* BRK */
    change_radio_state(RS_BASE, SS_RECV_WAIT);
  }

  async event void Panic.hook() { }
}
