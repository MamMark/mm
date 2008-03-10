/*
 * Copyright (c) 2008, Eric B. Decker
 * All rights reserved.
 */

#include "regime.h"

module mm3C {
  provides {
    interface Init;
  }
  uses {
    interface Regime;
    interface Leds;
    interface Boot;
    interface HplMM3Adc as HW;
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
    call Regime.setRegime(SNS_DEFAULT_REGIME);
    call Leds.led0Off();
    call Leds.led1Off();
    call Leds.led2Off();

    call HW.set_dmux(5);
    call HW.set_dmux(0);
    call HW.set_smux(5);
    call HW.set_smux(2);
    call HW.set_smux(0);
    call HW.set_gmux(2);
    call HW.set_gmux(0);
    call HW.batt_on();
    call HW.batt_off();
    call HW.temp_on();
    call HW.temp_off();
    call HW.sal_on();
    call HW.sal_off();
    call HW.accel_on();
    call HW.accel_off();
    call HW.ptemp_on();
    call HW.ptemp_off();
    call HW.press_on();
    call HW.press_off();
    call HW.speed_on();
    call HW.speed_off();
    call HW.mag_on();
    call HW.mag_off();
  }


  event void Regime.regimeChange() {}
}
