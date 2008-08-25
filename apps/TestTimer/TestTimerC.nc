
#include "Timer.h"

#define T1 (30*1024UL)
#define T2 (60*1024UL)
#define T3 (120*1024UL)

module TestTimerC {
  uses {
    interface Timer<TMilli> as Timer0;
    interface Timer<TMilli> as Timer1;
    interface Timer<TMilli> as Timer2;
  }
  uses interface Boot;
}

implementation {

  event void Boot.booted() {
    call Timer0.startOneShot( T1 );
    call Timer1.startOneShot( T2 );
    call Timer2.startOneShot( T3 );
  }

  event void Timer0.fired() {
    nop();
    call Timer0.startOneShot( T1 );
  }
  
  event void Timer1.fired() {
    nop();
    call Timer1.startOneShot( T2 );
  }
  
  event void Timer2.fired() {
    nop();
    call Timer2.startOneShot( T3 );
  }
}
