/*
 * Copyright (c) 2012, 2014 Eric B. Decker
 * All rights reserved.
 */

#include "mm5tPortRegs.h"

uint32_t gt0, gt1;
uint16_t tt0, tt1;

module testGPSP {
  provides interface Init;
  uses {
    interface Boot;
    interface StdControl as GPSControl;
    interface Timer<TMilli> as testTimer;
    interface LocalTime<TMilli>;
    interface Hpl_MM_hw as HW;
  }
}

implementation {
  enum {
    OFF = 0,
    STARTING,
    WAITING,
    STOPPING,
  };

  int state;

  task void test_task() {
    nop();
    gt0 = call LocalTime.get();
    tt0 = TA1R;
    ORG_GPS_RESET;
    ORG_GPS_UNRESET;
    while (1) {
      if (ORG_GPS_WAKEUP == 0)
	break;
    }
    tt1 = TA1R;
    gt1 = call LocalTime.get();
    nop();
  }

  command error_t Init.init() {
    return SUCCESS;
  }

  event void Boot.booted() {
    call testTimer.startOneShot(0);
  }


  event void testTimer.fired() {
    switch(state) {
      case OFF:
	state = STARTING;
	call GPSControl.start();
	call testTimer.startOneShot(0);
	break;

      case STARTING:
	state = WAITING;
	call testTimer.startOneShot(10000);
	break;

      case WAITING:
	state = STOPPING;
//	call GPSControl.stop();
	call testTimer.startOneShot(1000);
	break;

      case STOPPING:
	state = OFF;
//	call testTimer.startOneShot(1000);
	break;
    }
  }
}
