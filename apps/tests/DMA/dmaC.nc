/*
 * Copyright (c) 2008, 2010, Eric B. Decker
 * All rights reserved.
 */

#include "msp430usci.h"

configuration dmaC {}

implementation {
  components dmaP as App;
  components MainC;
  App.Boot -> MainC.Boot;

  components HplMsp430UsciB0C as UsciC;
  App.Usci -> UsciC;
  App.Interrupts -> UsciC;
}
