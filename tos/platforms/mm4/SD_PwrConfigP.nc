/*
 * Copyright 2010, Eric B. Decker
 * All rights reserved.
 *
 * SD_PwrConfigP: handle powering on/off the SD and associated configuration
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

#include "panic.h"

module SD_PwrConfigP {
  uses {
    interface ResourceDefaultOwner;
    interface SDreset;
    interface Hpl_MM_hw as HW;
    interface HplMsp430UsciB as Usci;
    interface Panic;
  }
}

implementation {

#define SPI_8MIHZ_DIV    1

  const msp430_spi_union_config_t sd_full_config = { {
    ubr		: SPI_8MIHZ_DIV,	/* full speed */
    ucmode	: 0,			/* 3 pin master, no ste */
    ucmst	: 1,
    uc7bit	: 0,			/* 8 bit */
    ucmsb	: 1,			/* msb first, compatible with msp430 usart */
    ucckpl	: 0,			/* inactive state low */
    ucckph	: 1,			/* data captured on rising, changed falling */
    ucssel	: 2,			/* smclk */
    } };

  /*
   * .granted: power down the SD.
   *
   * reconfigure connections to the SD as input to avoid powering the chip
   * and power off.
   *
   * The HW.sd_off routine will put the i/o pins into a reasonable state to
   * avoid powering the SD chip and will kill power.  Also make sure that
   * the SPI module is held in reset.
   */
  async event void ResourceDefaultOwner.granted() {
    call HW.sd_off();
    call Usci.resetUsci_n();
  }

  task void sd_pwr_task() {
    error_t err;

    if ((err = call SDreset.reset()))
      call Panic.panic(PANIC_MS, 0x80, err, 0, 0, 0);
  }

  async event void ResourceDefaultOwner.requested() {
    call HW.sd_on();
    call Usci.setModeSpi((msp430_spi_union_config_t *) &sd_full_config);
    post sd_pwr_task();
  }

  async event void ResourceDefaultOwner.immediateRequested() {
    call ResourceDefaultOwner.release();
  }

  event void SDreset.resetDone(error_t err) {
    if (err)
      call Panic.panic(PANIC_MS, 0x81, err, 0, 0, 0);
    call ResourceDefaultOwner.release();
  }
}
