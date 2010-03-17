/**
 *
 * Copyright 2008 (c) Eric B. Decker
 * All rights reserved.
 *
 * @author Eric B. Decker
 */

#include "hardware.h"

configuration PlatformLedsC {
  provides interface GeneralIO as Led0;
  provides interface GeneralIO as Led1;
  provides interface GeneralIO as Led2;
  uses interface Init;
}

implementation
{
  components PlatformP;

  Init = PlatformP.LedsInit;
  Led0 = PlatformP.Led0;
  Led1 = PlatformP.Led1;
  Led2 = PlatformP.Led2;
}
