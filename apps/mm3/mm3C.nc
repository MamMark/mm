/*
 * Copyright (c) 2008, Eric B. Decker
 * All rights reserved.
 */

#include "regime.h"

module mm3C {
  provides {
    interface Init;
  }
  uses {
    interface Regime;
    interface Leds;
    interface Boot;
  }
}

implementation {
  command error_t Init.init() {
    return SUCCESS;
  }


  event void Boot.booted() {
    /*
     * set the initial regime.  This will also
     * signal all the sensors and start them off.
     */
    call Regime.setRegime(SNS_DEFAULT_REGIME);
    call Leds.led0Off();
    call Leds.led1Off();
    call Leds.led2Off();
  }


  event void Regime.regimeChange() {}
}
