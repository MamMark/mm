
#include "Timer.h"

module mm3C {

  uses {
    interface HplMM3Adc as HW;
    interface Regime;

    interface StdControl as BattSense;
    interface StdControl as TempSense;
    interface StdControl as SalSense;
    interface StdControl as AccelSense;
    interface StdControl as PTempSense;
    interface StdControl as PressSense;
    interface StdControl as SpeedSense;
    interface StdControl as MagSense;

    interface Leds;
    interface Boot;
  }

  provides interface Init;
}

implementation {
  command error_t Init.init() {
    return SUCCESS;
  }


  event void Boot.booted() {
    call BattSense.start();
    call TempSense.start();
    call SalSense.start();
    call AccelSense.start();
    call PTempSense.start();
    call PressSense.start();
    call SpeedSense.start();
    call MagSense.start();

//    call Regime.setRegime(3);
    call Leds.led0Off();
    call Leds.led1Off();
    call Leds.led2Off();
  }


  event void Regime.regimeChange() {
    uint8_t t;

    t = call Regime.getCurRegime();
  }
}
