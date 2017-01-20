/*
 * Copyright (c) 2012, 2014, 2015 Eric B. Decker
 * All rights reserved.
 */

uint32_t gt0, gt1;
uint16_t tt0, tt1;

module testGPSP {
  provides interface Init;
  uses {
    interface Boot;
    interface StdControl as GPSControl;
    interface Timer<TMilli> as testTimer;
    interface LocalTime<TMilli>;
    interface Gsd4eUHardware as HW;
    interface Platform;
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
  }

  command error_t Init.init() {
    return SUCCESS;
  }

#ifdef TESTGPSP_RESET_CAPTURE_RESET
  uint8_t bytes[8096];
  volatile uint32_t wait = 1;

  event void Boot.booted() {
    uint32_t nxt, t0;

//    bkpt();

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

//    bkpt();

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

  async event   void    HW.byte_avail(uint8_t byte) { };
  async event   void    HW.receive_done(uint8_t *ptr, uint16_t len, error_t err) { };
  async event   void    HW.send_done(uint8_t *ptr, uint16_t len, error_t error) { };
}
