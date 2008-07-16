/*
 * Copyright (c) 2008, Eric B. Decker
 * All rights reserved.
 */

#include "panic.h"

module testGPSP {
  provides interface Init;
  uses {
    interface Boot;
    interface Panic;
    interface SplitControl as GPSControl;
    interface StreamStorageFull;
    interface mm3CommData;
  }
}

implementation {

  command error_t Init.init() {
//    call Panic.brk();
    return SUCCESS;
  }

  event void GPSControl.startDone(error_t error) {
  }

  event void GPSControl.stopDone(error_t error) {
  }

  event void mm3CommData.send_data_done(error_t rtn) { }

  event void StreamStorageFull.dblk_stream_full () {
  }

  event void Boot.booted() {
    call GPSControl.start();
    call GPSControl.stop();
    return;
  }
}
