/*
 * Copyright (c) 2015 Eric B. Decker
 * All rights reserved.
 */

uint32_t gt0, gt1;
uint16_t tt0, tt1;

module testRadioP {
  provides interface Init;
  uses {
    interface Boot;
    interface Timer<TMilli> as testTimer;
    interface LocalTime<TMilli>;
    interface RadioState;
    interface Panic;
  }
}

implementation {
  typedef enum {
    OFF = 0,
    STARTING,
    START_WAIT,
    STARTED,
    TX,
    RX,
    STANDBY,
    STANDBY_WAIT,
    STOPPING,
  } test_state_t;

  norace test_state_t state;

  command error_t Init.init() {
    return SUCCESS;
  }

  event void Boot.booted() {
    call testTimer.startOneShot(0);
  }


  task void change_state() {
    switch(state) {
      case START_WAIT:
        state = STANDBY_WAIT;
        call testTimer.startOneShot(1000);
        call RadioState.standby();
        break;

      case STANDBY_WAIT:
        state = STOPPING;
        call testTimer.startOneShot(1000);
        call RadioState.turnOff();
        break;

      case STOPPING:
        state = OFF;
        call testTimer.stop();
        break;

      default:
        call Panic.panic(-1, 1, state, 0, 0, 0);
        break;
    }
  }


  async event void RadioState.done() {
    switch(state) {
      case START_WAIT:
      case STANDBY_WAIT:
      case STOPPING:
        post change_state();
        break;

      default:
        call Panic.panic(-1, 2, state, 0, 0, 0);
        break;
    }
  }


  event void testTimer.fired() {
    nop();
    switch(state) {
      case OFF:
	state = START_WAIT;
	call testTimer.startOneShot(1000);
        call RadioState.turnOn();
	break;

      case STARTING:
      case START_WAIT:
        call Panic.panic(-1, 3, state, 0, 0, 0);
	state = STARTED;
	call testTimer.startOneShot(1000);
	break;

      case STARTED:
      case TX:
      case RX:
      case STANDBY:
      case STANDBY_WAIT:
        call Panic.panic(-1, 4, state, 0, 0, 0);
        state = STANDBY;
        call testTimer.startOneShot(1000);
        break;

        state = STANDBY_WAIT;
        call testTimer.startOneShot(1000);
        call RadioState.standby();
        break;

      case STOPPING:
        call RadioState.turnOff();
	state = OFF;
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
