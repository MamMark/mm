/*
 * Copyright 2010, Eric B. Decker
 * All rights reserved.
 *
 * DefaultOwner functions for the SD and SPI0 are handled by the SD driver
 * in SDspP.  This configuration exports the required interfaces and wires
 * them to the appropriate h/w interface.
 *
 * SD_ArbC provides an provides the corresponding arbitrated interface to
 * SD mass storage.
 */

#include "msp430usci.h"

configuration SPI0_OwnerC {
  provides {
    interface ResourceDefaultOwner;
    interface HplMsp430UsciB as Usci;
  }
}

implementation {
  components Msp430UsciShareB0P;
  ResourceDefaultOwner = Msp430UsciShareB0P;

  components HplMsp430UsciB0C;
  Usci = HplMsp430UsciB0C;
}
