
uint32_t gt0, gt1;
uint32_t tt0, tt1;

module testDockP {
  uses {
    interface Boot;
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

  task void test_task() {
    gt0 = call LocalTime.get();
    tt0 = call Platform.usecsRaw();
  }

  event void Boot.booted() {
    call testTimer.startOneShot(0);
  }


  event void testTimer.fired() {
    switch(state) {
      case OFF:
	state = STARTING;
        post test_task();
	call testTimer.startOneShot(0);
	break;

      case STARTING:
	state = WAITING;
        post test_task();
	call testTimer.startOneShot(10000);
	break;

      case WAITING:
	state = STOPPING;
        post test_task();
	call testTimer.startOneShot(1000);
	break;

      case STOPPING:
        post test_task();
	state = OFF;
	break;
    }
  }
}
