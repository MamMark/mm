/*
 * Copyright (c) 2017-2018, Eric B. Decker, Daniel J. Maltbie
 * All rights reserved.
 */


#include <Tasklet.h>
#include <platform_panic.h>

uint32_t gt0, gt1;
uint16_t tt0, tt1;

uint16_t global_node_id = 42;

#ifndef PANIC_TAGNET
enum {
  __pcode_tagnet = unique(UQ_PANIC_SUBSYS)
};

#define PANIC_TAGNET __pcode_tagnet
#endif

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
    //    interface Timer<TMilli> as pgTimer;
    interface LocalTime<TMilli>;
    interface Leds;
    interface Panic;
    interface Random;
    interface RadioState;
    interface RadioPacket;
    interface RadioSend;
    interface RadioReceive;
    interface Platform;
  }
}

implementation {
  /*
   * radio state info
  */
  typedef enum {
    OFF = 0,
    STARTING,
    ACTIVE,
    STOPPING,
    STANDBY,
  } radio_state_t;

  norace radio_state_t radio_state;

  /*
   * message buffer
   *
   * Exchanged with radio driver every receive call.
   */
  norace volatile uint8_t     tagMsgBuffer[sizeof(message_t)];
  norace volatile uint8_t     tagMsgBufferGuard[] = "DEADBEAF";
  norace message_t          * pTagMsg = (message_t *) tagMsgBuffer;
  norace          uint8_t     tagMsgBusy, tagMsgSending;
                  uint32_t    tagmon_timeout  = 20; // milliseconds

  task void network_task() {
    if (call Tagnet.process_message(pTagMsg)) {
      /*
       * if the message processor returns TRUE that says the message now contains
       * the outgoing response.  Fire the turn around timer which kicks the
       * sender.
       *
       * Don't mark the current msg buffer until the sender finishes.
       */
      call rcTimer.startOneShot(tagmon_timeout); /* fire up turn around timer */
      return;
    }

    /*
     * The message processor says no return message just mark the buffer as
     * available and be done with it.
     */
    tagMsgBusy = FALSE;
  }

  tasklet_async event void RadioSend.ready() {
    nop();
  }

  tasklet_async event void RadioSend.sendDone(error_t error) {
    nop();
    if (!tagMsgBusy)
      call Panic.panic(PANIC_TAGNET, 191, (parg_t) pTagMsg, 0, 0, 0);

    tagMsgSending = FALSE;              /* informational state */
    tagMsgBusy    = FALSE;              /* say this buffer available */
  }

  tasklet_async event message_t* RadioReceive.receive(message_t *msg) {
    message_t    * pNextMsg;
    nop();
    nop();                     /* BRK */
    if (!msg)
      call Panic.panic(PANIC_TAGNET, 192, 0, 0, 0, 0);

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
    nop();
  }

  event void rcTimer.fired() {
    error_t err;

    tagMsgSending = TRUE;
    err = call RadioSend.send(pTagMsg);
    if (err)
      call Panic.panic(PANIC_TAGNET, 190, err, 0, 0, 0);
  }

  event void txTimer.fired() {
    nop();
    nop();
  }


  event void Boot.booted() {
    error_t     error;

    error = call RadioState.turnOn();
    if (error)
      call Panic.panic(PANIC_TAGNET, 194, (uint32_t) error, 0, 0, 0);
  }

  async event void Panic.hook() { }
}
