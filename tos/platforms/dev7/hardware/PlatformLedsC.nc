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

  /* RED LED (LED2 RED) at P2.0 */
  components new Msp432GpioC() as Led0Impl;
  Led0Impl -> GpioC.Port20;
  PlatformLedsP.Led0 -> Led0Impl;

  /* GREEN LED (LED2 GREEN) at P2.1 */
  components new Msp432GpioC() as Led1Impl;
  Led1Impl -> GpioC.Port21;
  PlatformLedsP.Led1 -> Led1Impl;

  /* BLUE LED (LED2 BLUE) at P2.2 */
  components new Msp432GpioC() as Led2Impl;
  Led2Impl -> GpioC.Port22;
  PlatformLedsP.Led2 -> Led2Impl;
}
