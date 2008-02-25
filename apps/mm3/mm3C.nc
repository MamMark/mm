// -*- mode:c; indent-tabs-mode:nil; c-basic-offset: 2 -*- 

#include "Timer.h"

module mm3C {

  uses interface HplMM3Adc as HW;
  uses interface mm3Regime as Regime;

#ifdef notdef
  uses interface mm3Pwr as C1;
  uses interface mm3Pwr as C2;
#endif

  uses interface StdControl as BattSense;
  uses interface StdControl as TempSense;
  uses interface StdControl as SalSense;
  uses interface StdControl as AccelSense;
  uses interface StdControl as PTempSense;
  uses interface StdControl as PressSense;
  uses interface StdControl as SpeedSense;
  uses interface StdControl as MagSense;


  uses interface Timer<TMilli> as Timer1;
  uses interface Timer<TMilli> as Timer2;
//  uses interface Alarm<T32khz, uint32_t> as Alarm2;
  uses interface Leds;
  uses interface Boot;
  uses interface Random;
  uses interface ParameterInit<uint16_t> as SeedInit;

  provides interface Init;
}

implementation {
  uint8_t counter;
  uint8_t c1, c2;

  command error_t Init.init() {
    counter = c1 = c2 = 0;
    call SeedInit.init(0);
    return SUCCESS;
  }

  event void Timer1.fired() {
    call Leds.led1Off();
//    call C1.release();
//    call C2.request();
  }

  event void Timer2.fired() {
    call Leds.led2Off();
//    call C2.release();
//    call C1.request();
  }


#ifdef notdef
  event void C1.granted() {
    c1++;
    call Leds.led1On();
    call Timer1.startOneShot(10000UL);
  }
  
  event void C2.granted() {
    c2++;
    call Leds.led2On();
    call Timer2.startOneShot(100UL);
  }
#endif

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
//    call C2.request();
//    call C1.request();
  }


  event void Regime.regimeChange() {
    uint8_t t;

    t = call Regime.getCurRegime();
  }


#ifdef notdef
  async event void Alarm2.fired() {
    call Alarm2.start( 32768UL );
    call Leds.led1Toggle();
  }
#endif
}
