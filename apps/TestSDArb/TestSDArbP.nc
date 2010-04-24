/*
 * Copyright (c) 2008, Eric B. Decker
 * All rights reserved.
 */

module TestSDArbP {
  uses {
    interface Boot;
    interface Resource;
    interface Timer<TMilli>;
  }
}

implementation {

  event void Boot.booted() {
    call Resource.request();
  }

  event void Resource.granted() {
    call Timer.startOneShot(1024);
  }

  event void Timer.fired() {
    call Resource.release();
    call Resource.request();
  }
}
