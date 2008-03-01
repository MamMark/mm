/*
 * Copyright (c) 2008, Eric B. Decker
 * All rights reserved.
 */

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
    call Regime.setRegime(4);
    call Leds.led0Off();
    call Leds.led1Off();
    call Leds.led2Off();
  }
  event void Regime.regimeChange() {}
}
