/*
 * Copyright (c) 2010 Eric B. Decker
 * All rights reserved.
 */

/**
 * @author Eric B. Decker <cire831@gmail.com>
 * @date March 21, 2010
 */

#ifndef XWAIT
#define XWAIT 0
#endif


uint8_t wait = XWAIT;


module CommBootP {
  provides interface Boot as CommBoot;
  uses {
    interface Boot;
    interface SplitControl as DockSerial;
    interface Panic;
  }
}
implementation {
  event void Boot.booted() {
    while (wait) {
      nop();
    }
#ifdef TEST_NO_COMM
    signal CommBoot.booted();
#else
    call DockSerial.start();
#endif
  }


  event void DockSerial.startDone(error_t err) {
    if (err) {
      call Panic.panic(PANIC_COMM, 1, err, 0, 0, 0);
      return;
    }
    signal CommBoot.booted();
  }


  event void DockSerial.stopDone(error_t err) {
    call Panic.panic(PANIC_COMM, 2, err, 0, 0, 0);
  }
}
