/*
 * Copyright (c) 2008, Eric B. Decker
 * All rights reserved.
 */

#include "regime.h"

#define NUM_RES 16
uint16_t res[NUM_RES];

module mm3C {
  provides {
    interface Init;
  }
  uses {
    interface Regime;
    interface Leds;
    interface Boot;
    interface HplMM3Adc as HW;

    interface Adc;
  }
}

implementation {
  command error_t Init.init() {
    return SUCCESS;
  }


  event void Boot.booted() {
    /*
     * set the initial regime.  This will also
     * signal all the sensors and start them off.
     */
    call Regime.setRegime(0);

    call Leds.led0Off();
    call Leds.led1Off();
    call Leds.led2Off();

    call HW.vdiff_on();
    call HW.vref_on();
    call HW.accel_on();
    call HW.set_smux(SMUX_ACCEL_X);
    uwait(1000);
    while(1) {
      uint16_t i;

      for (i = 0; i < NUM_RES; i++)
	res[i] = call Adc.readAdc();
      nop();
    }
  }

  event void Adc.configured() {}


  event void Regime.regimeChange() {}
}
