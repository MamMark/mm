/*
 * Copyright (c) 2012, 2014, 2015 Eric B. Decker
 * Copyright (c) 2017 Daniel J. Maltbie, Eric B. Decker
 * All rights reserved.
 */

uint32_t gt0, gt1;
uint16_t tt0, tt1;
uint32_t recv_count;

module testGPSP {
  provides interface TagnetAdapter<tagnet_gps_xyz_t> as InfoSensGpsXYZ;
  uses {
    interface Boot;
    interface GPSState;
    interface GPSReceive;
    interface Timer<TMilli> as testTimer;
    interface LocalTime<TMilli>;
#ifdef notdef
    interface Gsd4eUHardware as HW;
#endif
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

  int               state;
  uint32_t          m_x, m_y, m_z;

  task void test_task() {
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
	call GPSState.turnOn();
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


  command bool InfoSensGpsXYZ.get_value(tagnet_gps_xyz_t *t, uint8_t *l) {
    t->gps_x = m_x;
    t->gps_y = m_y;
    t->gps_z = m_z;
    *l = TN_GPS_XYZ_LEN;
  }


  event void GPSReceive.msg_available(uint8_t *msg, uint16_t len,
        uint32_t arrival_ms, uint32_t mark_j) {
    nop();
    recv_count++;
    m_x = recv_count;
    m_y = m_x + 1;
    m_z = m_y + 1;
  }
}
