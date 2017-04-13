/*
 * Copyright (c) 2012, 2014, 2015 Eric B. Decker
 * Copyright (c) 2017 Daniel J. Maltbie, Eric B. Decker
 * All rights reserved.
 */

#include "GPSMsgBuf.h"

uint32_t gt0, gt1;
uint16_t tt0, tt1;

module testGPSP {
  provides interface Init;
  uses {
    interface Boot;
    interface StdControl as GPSControl;
    interface Timer<TMilli> as testTimer;
    interface LocalTime<TMilli>;
#ifdef notdef
    interface Gsd4eUHardware as HW;
#endif
    interface Platform;
    interface GPSReceive;
  }
}

implementation {
  enum {
    OFF = 0,
    STARTING,
    WAITING,
    STOPPING,
  };

  int               state;
  norace gps_msg_t *p_msg;
  uint32_t          recv_count;

  task void test_task() {
    nop();
    // call Collect.collect();
    call GPSReceive.receive_done(p_msg);
    recv_count++;

#ifdef notdef
    gt0 = call LocalTime.get();
    tt0 = call Platform.usecsRaw();
    call HW.gps_set_reset();
    call HW.gps_clr_reset();
    while (1) {
      if (call HW.gps_awake())
        continue;
      break;
    }
    tt1 = call Platform.usecsRaw();
    gt1 = call LocalTime.get();
    nop();
#endif
  }

  command error_t Init.init() {
    recv_count = 0;
    return SUCCESS;
  }

#ifdef TESTGPSP_RESET_CAPTURE_RESET
  uint8_t bytes[8096];
  volatile uint32_t wait = 1;

  event void Boot.booted() {
    uint32_t nxt, t0;

//    ROM_DEBUG_BREAK(0);

    nop();
    nop();
    call HW.gps_pwr_on();
    call HW.gps_speed_di(57600);
    call HW.gps_set_reset();
    t0 = call Platform.usecsRaw();
    while (call Platform.usecsRaw() - t0 < 105) ;
    call HW.gps_clr_reset();

    t0 = call Platform.usecsRaw();
    while (call Platform.usecsRaw() - t0 < 2048) ;

    call HW.gps_set_on_off();
    t0 = call Platform.usecsRaw();
    while (call Platform.usecsRaw() - t0 < 105) ;
    call HW.gps_clr_on_off();

    nxt = 0;
    while (1) {
      if (EUSCI_A0->IFG & EUSCI_A_IFG_RXIFG) {
        bytes[nxt++] = EUSCI_A0->RXBUF;
        if (nxt >= 8096)
          nxt = 0;
        if (wait)
          wait++;
        if (wait > 32) {
          call HW.gps_set_reset();
          t0 = call Platform.usecsRaw();
          while (call Platform.usecsRaw() - t0 < 105) ;
          call HW.gps_clr_reset();
          wait = 0;
        }
      }
    }
  }

#else

  event void Boot.booted() {

    call testTimer.startOneShot(0);
  }
#endif


//  event void GPSControl.startDone(error_t err) { }
//  event void GPSControl.stopDone(error_t err) { }

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

  async event   void     GPSReceive.receive(gps_msg_t *ptr) {
    p_msg = ptr;
    post test_task();
  }
}
