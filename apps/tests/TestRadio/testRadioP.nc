/*
 * Copyright (c) 2015 Eric B. Decker
 * All rights reserved.
 */


#include <Tasklet.h>

uint32_t gt0, gt1;
uint16_t tt0, tt1;

module testRadioP {
  provides {
    interface Init;
  } uses {
    interface Boot;
    interface Timer<TMilli> as rcTimer;
    interface Timer<TMilli> as txTimer;
    interface LocalTime<TMilli>;
    interface Leds;
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

  uint16_t        test_iterations, test_tx_errors, test_rx_errors, test_tx_busy;
  uint16_t        transmit_iterations, receive_iterations;
  uint16_t        iteration_modulo = 10;
  uint8_t         active_mode;
  uint16_t        wait_time, tx_time;

  message_t     * rxMsg;            /* msg driver owns */
  uint8_t         txMsgBuffer[129] = {'\31', '\1', 'H', 'e', 'l', 'l', 'o', 'H', 'e', 'l', 'l', 'o', 'H', 'e', 'l', 'l', 'o', 'H', 'e', 'l', 'l', 'o', 'H', 'e', 'l', 'l', 'o', 'H', 'e', 'l', 'l', 'o', '\0'};
  message_t     * txMsg = (message_t *) txMsgBuffer;

  /*
   * state info
   */
  typedef enum {
    OFF = 0,
    STARTING,
    WAITING,
    STOPPING,
  } test_state_t;

  norace test_state_t state;

  typedef enum {
    DISABLED = 0,
    RUN = 1,
    PING = 2,
    PONG = 4,
  } test_mode_t;

  /*
   * packet test transmission is controlled by timer interrupt.
   *
   */
  typedef struct {
    uint32_t        iterations;
    uint32_t        pings;
    uint16_t        delay;
    uint16_t        error;
    uint16_t        errors;
    uint16_t        busy;
    uint8_t         size;
    test_mode_t     mode;
  } tx_t;

  norace tx_t       tx;

  void tx_start() {
    nop();
    if (tx.mode)
      call txTimer.startOneShot(tx.delay);
  }

  void tx_stop() {
    nop();
    // cancel timer
  }


  task void tx_task() {
    nop();
    nop();
    if ((tx.mode == RUN) || (tx.mode == PING)) {
      tx.error = call RadioSend.send(txMsg);
      if (tx.error == SUCCESS) {
	call Leds.led0Toggle();
      } else if (tx.error == EALREADY) {
	tx.busy++;
      } else {
	call Panic.panic(-1, 4, state, tx.error, tx.errors++, tx.iterations);
      }
    }
    if (tx.mode == PING) {
      tx.mode = PONG;
    } else if (tx.mode == PONG) {
      tx.errors++;
      tx.mode = PING;
    }
    call txTimer.startOneShot(tx.delay);
  }


  event void txTimer.fired() {
    post tx_task();
  }

  tasklet_async event void RadioSend.ready() { }

  tasklet_async event void RadioSend.sendDone(error_t error) {
    nop();
    nop();
    if (error) {
      tx.errors++;
      tx.error = error;
    }
    tx.iterations++;
  }


  /*
   * packet test reception is handled by event callback
   *
   */
  typedef struct {
    uint32_t        iterations;
    test_mode_t     mode;
    uint8_t         enable;
  } rx_t;

  norace rx_t     rx;

  void rx_start() {
    nop();
  }

  void rx_stop() {
    nop();
  }

  tasklet_async event message_t* RadioReceive.receive(message_t *msg) {
    nop();
    nop();
    if (rx.mode == RUN) {
      rx.iterations++;
      call Leds.led1Toggle();
    }
    if (tx.mode == PONG) {
      tx.pings++;
      tx.mode = PING;
    }
    return msg;
  }

  tasklet_async event bool RadioReceive.header(message_t *msg) {
    nop();
    return TRUE;
  }

  /*
   * radio control state is cycled periodically
   *
   */

  typedef struct {
    uint16_t        iterations;
    uint16_t        starts;
    uint16_t        errors;
    uint16_t        last_error;
    uint16_t        delay;
    uint16_t        modulo;
  } rc_t;

  norace rc_t     rc;

  void task rc_task() {
    nop();
    nop();
    switch(state) {
    case STARTING:
      call Leds.led0Off();
      call Leds.led1Off();
      call Leds.led2Off();
      state = WAITING;
      tx_start();
      rx_start();
      call rcTimer.startOneShot(rc.delay);
      break;
    case STOPPING:
      call Leds.led0On();
      call Leds.led1On();
      call Leds.led2On();
      state = OFF;
      tx_stop();
      rx_stop();
      call rcTimer.startOneShot(rc.delay);
      break;
    default:
      nop();
      call Panic.panic(-1, 1, state, 0, 0, 0);
      state = OFF;
      call rcTimer.startOneShot(rc.delay);
      break;
    }
  }

  async event void RadioState.done() {
    post rc_task();
  }

  event void rcTimer.fired() {
    nop();
    nop();
    switch(state) {
    case OFF:
      nop();
      call Leds.led0On();
      call Leds.led1On();
      call Leds.led2On();
      rc.starts++;
      state = STARTING;
      call rcTimer.startOneShot(rc.delay);
      rc.last_error = call RadioState.turnOn();
      break;
    case WAITING:
      nop();
      if ((rc.iterations++ % rc.modulo) == 0) {
	call Leds.led0On();
	call Leds.led1On();
	call Leds.led2On();
	nop();
	state = STOPPING;
	rc.last_error = call RadioState.turnOff();
      } else {
	call rcTimer.startOneShot(rc.delay);
      }
      break;
    default:
      nop();
      call Panic.panic(-1, 3, state, 0, 0, 0);
      state = OFF;
      call rcTimer.startOneShot(rc.delay);
      break;
    }
  }


  /*
   * operating system hooks
   */
  command error_t Init.init() {
    return SUCCESS;
  }

  event void Boot.booted() {
    nop();
    nop();
    tx.mode    = PING;    // enable transmission
    rx.mode    = RUN;     // enable reception
    tx.delay   = 100;     // set timeout between transmssions
    rc.delay   = 5000;    // set timeout between radio checks
    rc.modulo  = 100;     // power cycle every nth check
    call rcTimer.startOneShot(0);
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
