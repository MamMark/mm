/**
 *
 * Copyright 2008 (c) Eric B. Decker
 * All rights reserved.
 *
 * @author Eric B. Decker
 */

#include "hardware.h"

configuration PlatformC {
  provides interface Init;
  provides interface BootParams;
}

implementation {
  components PlatformP, Msp430ClockC;

  Init = PlatformP;
  BootParams = PlatformP;
  PlatformP.ClockInit -> Msp430ClockC.Init;
  PlatformP.Msp430ClockInit -> Msp430ClockC;
}
