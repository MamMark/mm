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
    interface SpiByte;
    interface SpiPacket;
  }
}

implementation {
  enum {
    CLIENT_ID = unique(MSP430_SPI0_BUS),
  };

#ifdef ENABLE_SD_DMA
#warning "Enabling DMA for SD/SPI0 (usciB0)"
  components Msp430Spi0DmaP as SpiP;
#else
  components Msp430Spi0NoDmaP as SpiP;
#endif

  Resource = SpiP.Resource[CLIENT_ID];
  SpiByte = SpiP.SpiByte;
  SpiPacket = SpiP.SpiPacket[CLIENT_ID];

  /*
   * SD_ArbC provides arbited access to the SD on usciB0.  Pwr
   * control and configuration is handled by SD_PwrConfig.  Don't
   * wire in ResourceConfigure from SpiP because that would mess
   * with the configuration established by the DefaultOwner.
   */
  components new Msp430UsciB0C() as UsciC;
  SpiP.UsciResource[CLIENT_ID] -> UsciC.Resource;
  SpiP.UsciInterrupts -> UsciC.HplMsp430UsciInterrupts;
}
