/*
 * Copyright (c) 2020 Eric B. Decker
 * All rights reserved.
 */

module testGPSP {
  provides interface TagnetRadio;
  uses {
    interface Boot;
    interface GPSControl;
    interface Timer<TMilli> as testTimer;
    interface LocalTime<TMilli>;
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

  event void Boot.booted() {
    call testTimer.startOneShot(5 * 1024);
  }


  event void testTimer.fired() {
    switch(state) {
      case OFF:
	state = STARTING;
	call GPSControl.turnOn();
	call testTimer.startOneShot(0);
	break;

      case STARTING:
	state = WAITING;
	call testTimer.startOneShot(30 * 60 * 1024);
	break;

      case WAITING:
	state = STOPPING;
//        call GPSControl.turnOff();
	call testTimer.startOneShot(0);
	break;

      case STOPPING:
	state = OFF;
	call testTimer.startOneShot(60 * 1024);
	break;
    }
  }


  command void TagnetRadio.setHome()  { }
  command void TagnetRadio.setNear()  { }
  command void TagnetRadio.setLost()  { }
  command void TagnetRadio.shutdown() { }


  event void GPSControl.gps_booted()    { }
  event void GPSControl.gps_boot_fail() { }
  event void GPSControl.gps_shutdown()  { }
  event void GPSControl.standbyDone()   { }
  event void GPSControl.wakeupDone()    { }
}
