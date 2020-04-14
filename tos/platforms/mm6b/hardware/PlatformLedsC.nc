/*
 * Copyright (c) 2016 Eric B. Decker
 * All rights reserved.
 */

#include "hardware.h"

configuration PlatformLedsC {
  provides {
    interface Init;
    interface Leds;
  }
}
implementation {
  components PlatformLedsP;
  Leds = PlatformLedsP;
  Init = PlatformLedsP;

  components HplMsp432GpioC as GpioC;

  /*
   * mm6b doesn't have any leds on board.  just wiggle pins we
   * can see.
   */
  components new Msp432GpioC() as Led0Impl;
  Led0Impl -> GpioC.Port12;
  PlatformLedsP.Led0 -> Led0Impl;

  components new Msp432GpioC() as Led1Impl;
  Led1Impl -> GpioC.Port13;
  PlatformLedsP.Led1 -> Led1Impl;

  components new Msp432GpioC() as Led2Impl;
  Led2Impl -> GpioC.Port20;
  PlatformLedsP.Led2 -> Led2Impl;
}
