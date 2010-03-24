/*
 * Copyright (c) 2010 Eric B. Decker
 * All rights reserved.
 */

/**
 * @author Eric B. Decker <cire831@gmail.com>
 * @date March 21, 2010
 */

uint8_t wait;

module CommBootP {
  provides {
    interface Boot as CommBoot;
  }
  uses {
    interface Boot;
    interface mmCommSw;
  }
}
implementation {
  event void Boot.booted() {
    if (wait > 1)
      wait = 1;
    while (wait) {
      nop();
    }
#ifdef TEST_NO_COMM
    signal CommBoot.booted();
#else
    call mmCommSw.useSerial();
#endif
//    call mmCommSw.useRadio();

  }

  event void mmCommSw.serialOn() {
    signal CommBoot.booted();
  }

  event void mmCommSw.radioOn() {
//    signal CommBoot.booted();
  }

  event void mmCommSw.commOff() {}
}

