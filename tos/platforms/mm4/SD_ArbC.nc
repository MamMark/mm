/*
 * Copyright 2010, Eric B. Decker
 * All rights reserved.
 *
 * SD_ArbC provides an provides an arbitrated interface to the SD mass
 * storage that lives on SPI0, usciB0 on the 2618.
 *
 * supports multiple clients and handles automatic power up, reset,
 * and power down when no requests are pending.
 *
 * SD_ArbC uses SD_PwrConfigC to handle common power control, pin
 * twiddling, and configuration.
 *
 * SD_PwrConfigC gets wired in as the DefaultOwner in PlatformC.
 * Msp430UsciShareB0P <- Sd_PwrConfigC.
 */

#include "msp430usci.h"

generic configuration SD_ArbC() {
  provides {

    interface Resource;

    interface SDread;
    interface SDwrite;
    interface SDerase;
  }
}

implementation {
  enum {
    CLIENT_ID = unique(MSP430_HPLUSCIB0_RESOURCE),
  };

  /*
   * SD_ArbC provides arbited access to the SD on usciB0.  Pwr
   * control and configuration is handled by SD_PwrConfig.  Don't
   * wire in ResourceConfigure because that would mess
   * with the configuration established by the DefaultOwner.
   */
  components Msp430UsciShareB0P as UsciShareP;
  Resource = UsciShareP.Resource[CLIENT_ID];

  components SDspC as SD;
  SDread  = SD.SDread[CLIENT_ID];
  SDwrite = SD.SDwrite[CLIENT_ID];
  SDerase = SD.SDerase[CLIENT_ID];
}
