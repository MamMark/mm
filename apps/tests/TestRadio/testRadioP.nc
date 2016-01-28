/*
 * Copyright (c) 2015 Eric B. Decker
 * All rights reserved.
 */


#include <Si446xDriverLayer.h>
#include <Tasklet.h>
#include <RadioAssert.h>
#include <TimeSyncMessageLayer.h>
#include <RadioConfig.h>
#include <si446x.h>

uint32_t gt0, gt1;
uint16_t tt0, tt1;

module testRadioP {
  provides {
    interface Init;
  } uses {
    interface Boot;
    interface Timer<TMilli> as testTimer;
    interface LocalTime<TMilli>;
    interface Panic;
    interface RadioState;
    interface RadioPacket;
    interface RadioSend;
    interface RadioReceive;
//    interface RadioCCA;
//    interface RadioAlarm;
  }
}

implementation {

  uint16_t test_iterations, test_tx_errors, test_rx_errors, test_tx_busy;
  uint16_t transmit_iterations, receive_iterations;

  message_t  * rxMsg;            /* msg driver owns */
  uint8_t      txMsgBuffer[129] = {'\6','H', 'e', 'l', 'l', 'o', '\0'};
  message_t  * txMsg = (message_t *) txMsgBuffer;

  typedef enum {
    OFF = 0,
    STARTING,
    WAITING,
    TX,
    STOPPING,
  } test_state_t;

  norace test_state_t state;
  norace uint16_t     iteration_modulo = 10;

  command error_t Init.init() {
    return SUCCESS;
  }

  event void Boot.booted() {
    nop();
    call testTimer.startOneShot(0);
  }


  task void change_state() {
    error_t      error;

    nop();
    switch(state) {
    case STARTING:
      state = WAITING;
      call testTimer.startOneShot(1000);
      break;

    case STOPPING:
      state = OFF;
      call testTimer.startOneShot(1000);
      break;

    case TX:
      transmit_iterations++;
      if ((transmit_iterations % iteration_modulo) == 0) {
	nop();
	error = call RadioState.turnOff();
	state = STOPPING;
	call testTimer.startOneShot(1000);
	break;
      }
      state = WAITING;
      call testTimer.startOneShot(1000);
      break;

    default:
      nop();
      call Panic.panic(-1, 1, state, 0, 0, 0);
      break;
    }
  }


  async event void RadioState.done() {
    post change_state();
  }

  tasklet_async event void RadioSend.ready() { }

  tasklet_async event void RadioSend.sendDone(error_t error) {
    post change_state();
  }

  tasklet_async event bool RadioReceive.header(message_t *msg) {
    return TRUE;
  }

  tasklet_async event message_t* RadioReceive.receive(message_t *msg) {
    receive_iterations++;
    return msg;
  }


  event void testTimer.fired() {
    error_t      error;

    nop();
    switch(state) {
    case OFF:
      state = STARTING;
      call testTimer.startOneShot(1000);
      error = call RadioState.turnOn();
      break;
    case WAITING:
      nop();
      error = call RadioSend.send(txMsg);
      if (error == SUCCESS) {
	state = TX;
      } else if (error == EALREADY) {
	test_tx_busy++;
      } else {
	call Panic.panic(-1, 4, state, error, test_tx_errors, transmit_iterations);
      }
      call testTimer.startOneShot(1000);
      break;
    case TX:
      test_tx_errors++;
      state = WAITING;
      call testTimer.startOneShot(1000);
      break;
    case STARTING:
    case STOPPING:
      nop();
      call Panic.panic(-1, 3, state, 0, 0, 0);
      state = OFF;
      call testTimer.startOneShot(1000);
      break;
    }
  }


  async event void Panic.hook() {
#ifdef notdef
    dump_radio();
    call CSN.set();
    call CSN.clr();
    call CSN.set();
    drs(TRUE);
    nop();
#endif
  }
}
