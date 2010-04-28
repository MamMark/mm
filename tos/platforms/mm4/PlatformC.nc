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
}

implementation {
  components PlatformP, Msp430ClockC;

  Init = PlatformP;
  PlatformP.ClockInit -> Msp430ClockC.Init;
  PlatformP.Msp430ClockInit -> Msp430ClockC;

  /*
   * SD_PwrConfigC handles, pwr up/configuration, reset, and
   * pwr down/deconfiguration for the SD on ucsiB0.  It is
   * wired in as the DefaultOwner on usciB0's arbiter.
   */
  components SD_PwrConfigC as SDpwr;
  components Msp430UsciShareB0P as usciB0;
  SDpwr.ResourceDefaultOwner -> usciB0;
}
