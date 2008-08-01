/*
 * CradleP.nc: Are we plugged into the cradle
 * Copyright 2008 Eric B. Decker
 * All rights reserved.
 */


/**
 *  Cradle Monitor Sensor Driver
 *  @author: Eric B. Decker
 *
 * Detecting being plugged into the cradle uses the battery sensor hardware so
 * we are forced to go through the ADC/sensor system.
 *
 * It is just like the battery sensor with the following differences:
 *
 * 1) Cradle sensing doesn't turn on the battery fet.  If a voltage is present
 *    (adc is used to read) then we are in the cradle.
 *
 * 2) The cradle sensor always runs.  It doesn't pay attention to the entry in
 *    regime control.  We can change this and make use of the entry to tailor
 *    how often the cradle connect is looked at.
 */

#include "sensors.h"
#include "cradle.h"

module CradleP {
  provides {
    interface StdControl;
    interface Init;
    interface AdcConfigure<const mm3_sensor_config_t*>;
  }

  uses {
    interface Regime as RegimeCtrl;
    interface Timer<TMilli> as PeriodTimer;
    interface Adc;
    interface HplMM3Adc as HW;
    interface Panic;
  }
}

implementation {
  uint8_t  cradle_state;
  uint32_t err_overruns;
  bool     docked;


  command error_t Init.init() {
    period = 0;
    cradle_state = CRADLE_STATE_OFF;
    err_overruns = 0;
    docked = FALSE;
    return SUCCESS;
  }


  command error_t StdControl.start() {
    /*
     * sensing being in the cradle (docked) is done by reading the battery
     * but without switching the battery fet on.  If we are in the cradle
     * then we will see the charging voltage.
     *
     * call HW.batt_on();
     *
     * So we don't need to do anything when starting and stopping.
     */
    return SUCCESS;
  }


  command error_t StdControl.stop() {
    return SUCCESS;
  }


  event void PeriodTimer.fired() {
    if (cradle_state != CRADLE_STATE_IDLE) {
      err_overruns++;
      /*
       * bitch, shouldn't be here.  Of course it could be
       * because something took way too long.
       */
//      call Panic.brk();
      return;
    }
    cradle_state = CRADLE_STATE_READ;
    call Adc.reqConfigure();
  }


  event void Adc.configured() {
    uint16_t data;

    data = call Adc.readAdc();
    cradle_state = CRADLE_STATE_IDLE;
    call Adc.release();
  }


  event void RegimeCtrl.regimeChange() {
    uint32_t new_period;

    call PeriodTimer.stop();
    if (call Adc.isOwner())
      call Adc.release();
    cradle_state = CRADLE_STATE_IDLE;
    call PeriodTimer.startPeriodic(CRADLE_PERIOD);
  }


  async command const mm3_sensor_config_t* AdcConfigure.getConfiguration() {
    return &cradle_config;
  }
}
