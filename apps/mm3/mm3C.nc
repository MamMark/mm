/*
 * Copyright (c) 2008, Eric B. Decker
 * All rights reserved.
 */

#include "regime.h"
#include "panic.h"

#ifdef notdef
#define NUM_RES 16
uint16_t res[NUM_RES];
#endif

noinit uint8_t use_regime;

module mm3C {
  provides {
    interface Init;
  }
  uses {
    interface Regime;
    interface Leds;
    interface Boot;
    interface Panic;

    interface HplMM3Adc as HW;
    interface Adc;
  }
}

implementation {
  command error_t Init.init() {
//    call Panic.brk();
    return SUCCESS;
  }


  event void Boot.booted() {
    /*
     * set the initial regime.  This will also
     * signal all the sensors and start them off.
     */
//    call Regime.setRegime(SNS_DEFAULT_REGIME);
    if (use_regime > SNS_MAX_REGIME)
      use_regime = SNS_DEFAULT_REGIME;
    call Regime.setRegime(use_regime);

    call Leds.led0Off();
    call Leds.led1Off();
    call Leds.led2Off();

#ifdef notdef
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
#endif
  }

  event void Adc.configured() {
    call Panic.panic(PANIC_MISC, 1, 0, 0, 0, 0);
  }

  event void Regime.regimeChange() {} // do nothing.  that's okay.
}
