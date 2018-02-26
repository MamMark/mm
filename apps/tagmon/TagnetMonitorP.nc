/*
 * Copyright (c) 2015 Eric B. Decker
 * Copyright (c) 2017 Eric B. Decker, Daniel J. Maltbie
 * All rights reserved.
 */


#include <Tasklet.h>

uint32_t gt0, gt1;
uint16_t tt0, tt1;

uint16_t global_node_id = 42;

module TagnetMonitorP {
  provides {
    interface Init;
  } uses {
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
  norace volatile uint8_t     tagMsgBusy, tagMsgSending;
  norace volatile uint32_t    tagmon_timeout  = 20; // milliseconds

  task void network_task() {

    nop();
    if (tagMsgBusy && !tagMsgSending) {
      if (call Tagnet.process_message(pTagMsg)) {
        nop();
        call rcTimer.startOneShot(tagmon_timeout);
        nop();
      } else {
        tagMsgBusy = FALSE;
      }
    } else
      call Panic.panic(-1, 193, (int) pTagMsg, 0, 0, 0);
  }

  tasklet_async event void RadioSend.ready() {
    nop();
  }

  tasklet_async event void RadioSend.sendDone(error_t error) {
    nop();
    // free the msg for next receive
    if (tagMsgBusy && tagMsgSending) {
      tagMsgBusy = FALSE;
      tagMsgSending = FALSE;
    }
  }

  tasklet_async event message_t* RadioReceive.receive(message_t *msg) {
    message_t    * pNextMsg;
    nop();
    nop();                     /* BRK */
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
    nop();
    nop();
    call RadioSend.send(pTagMsg);
    tagMsgSending = TRUE;
  }

  event void txTimer.fired() {
    nop();
    nop();
  }

  /*
   * operating system hooks
   */
  command error_t Init.init() {
    return SUCCESS;
  }

  event void Boot.booted() {
   error_t     error;
    nop();
    nop();                      /* BRK */
    error = call RadioState.turnOn();
    if (error != 0) {
      call Panic.panic(-1, 194, (uint32_t) error, 0, 0, 0);
    }
  }

  async event void Panic.hook() {
  }
}
