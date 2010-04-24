/*
 * Copyright 2010, Eric B. Decker
 * All rights reserved.
 *
 * SD_ArbC provides an provides an arbitrated interface to the SD mass
 * storage that lives on SPI0, usciB0 on the 2618.
 *
 * supports multiple clients and handles automatic
 * power up, reset, and power down when no requests
 * are pending.
 *
 * SD_ArbC uses SD_PwrConfigC to handle common power control, pin
 * twiddling, and configuration.
 *
 * Power control, and resetting the SD is handled by
 * a default owner.  The default owner (SD_PwrConfigC) handles
 * power up, reset, and any configuration issues.  Client
 * configuration (SpiP.ResourceConfigure isn't wired which
 * prevents the tinyOS core files (ie. Msp430Spi0DmaP etc)
 * from configuring the SPI when the Arbiter signals
 * the grant.  Configuration is handled by PwrConfig.
 *
 * SD_PwrConfigC is responsbile for:
 *
 * a) configuring any h/w, SPI pins, i/o pins, etc.
 * b) powering up the SD.
 * c) resets the SD and handling any power up issues.
 *
 * When SD_PwrConfigC calls ResourceDefaultOwner.release
 * it indicates that the SD has been configured, powered
 * up, and is ready to accept commands for access.  This
 * indicates to the Arbiter that it is okay to start issuing
 * grants to requesters.
 *
 * When all requesters have finished, the last Resource.release
 * will cause the Arbiter to call ResourceDefaultOwner.granted
 * which tells SD_PwrConfigC to reclaim control.  It will
 * deconfigure and power the SD h/w down.
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

  components new Msp430UsciB0C() as UsciC;
  SpiP.UsciResource[CLIENT_ID] -> UsciC.Resource;
  SpiP.ResourceConfigure[CLIENT_ID] <- UsciC.ResourceConfigure;
  SpiP.UsciInterrupts -> UsciC.HplMsp430UsciInterrupts;

  components SD_PwrConfigC as Pwr;
  Pwr.ResourceDefaultOwner -> UsciC;
}
