/*
 * Copyright 2010, Eric B. Decker
 * All rights reserved.
 *
 * SD_PwrConfigC: handle powering on/off the SD and associated configuration
 * issues.  Also resets the interface making it ready for access.
 *
 * SD_ArbC provides an provides an arbitrated interface to the SD mass
 * storage that lives on SPI0, usciB0 on the 2618.
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

configuration SD_PwrConfigC {
  uses interface ResourceDefaultOwner;
}

implementation {
  components SD_PwrConfigP as Pwr;
  ResourceDefaultOwner = Pwr;

  components SDspC as SD;
  Pwr.SDreset -> SD;

  components Hpl_MM_hwC as HW;
  Pwr.HW -> HW;

  components HplMsp430UsciB0C as UsciC;
  Pwr.Usci -> UsciC;

  components PanicC;
  Pwr.Panic -> PanicC;
}
