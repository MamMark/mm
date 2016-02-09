/*
 * LedRailP
 *
 * Drives the PowerRail interface using a timer.
 */


module LedRailP {
  uses interface Boot;
  uses interface Timer<TMilli> as Timer0;
  uses interface PwrReg;
  uses interface Leds;
}
implementation {
  /* without initialization this seems to only get 1 byte allocated, eg (main.sym):
   * 00001110 B LedRailP__task_counter
   */
  uint32_t task_counter = 100000;

  /* make this big enough that we can see the task running */
  /* having this as a variable makes it easy to adjust in gdb */
  uint32_t task_max = 500000000;

  event void Boot.booted() {
    nop();
    /* Start timer used to toggle power request */
    call Timer0.startOneShot(2000);
  }

  event void Timer0.fired() {
    nop();
    /* toggle the power request */
    call PwrReg.pwrReq();
  }

  task void stuffDone() {
    nop();
    nop();
    nop();
    call Leds.led1Off();

    /* release demand for power */
    call PwrReg.pwrRel();

    /* start a timer for next time */
    call Timer0.startOneShot(2000);
  }

  task void doStuff() {
    uint32_t i;

    nop();
    nop();
    nop();

    /* Pretend to do stuff for a while */
    for (i=0; i < 5000; i++) {
      task_counter++;
    }

    if (task_counter < task_max) {
      post doStuff();
    } else {
      post stuffDone();
    }
  }

  event void PwrReg.pwrAvail() {
    nop();

    /* here we light up Led1 after getting this notification */
    /* if we add 2 timers we can light Led2 using the second timer */
    call Leds.led1On();

    /* do something and then release power */
    task_counter = 0;
    post doStuff();
  }
}
