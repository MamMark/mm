/* 
 * TempP.nc: implementation for temperature
 * Copyright 2008 Eric B. Decker
 * All rights reserved.
 */


/**
 *  Temperature Sensor Driver
 *  @author: Eric B. Decker
 */

#include "sensors.h"
#include "temp.h"

module TempP {
  provides {
    interface StdControl;
    interface Init;
    interface AdcConfigure<const mm3_sensor_config_t*>;
  }

  uses {
    interface Regime as RegimeCtrl;
    interface Timer<TMilli> as PeriodTimer;
    interface Adc;
    interface Collect;
  }
}

implementation {
  uint32_t period;
  uint8_t  temp_state;
  uint32_t err_overruns;


  command error_t Init.init() {
    period = 0;
    temp_state = TEMP_STATE_OFF;
    err_overruns = 0;
    return SUCCESS;
  }


  command error_t StdControl.start() {
    /* power up temp */
    return SUCCESS;
  }


  command error_t StdControl.stop() {
    /* power down temp */
    return SUCCESS;
  }


  event void PeriodTimer.fired() {
    if (temp_state != TEMP_STATE_IDLE) {
      err_overruns++;
      /*
       * bitch, shouldn't be here.  Of course it could be
       * because something took way too long.
       */
      return;
    }
    temp_state = TEMP_STATE_READ;
    call Adc.reqConfigure();
  }


  event void Adc.configured() {
    uint8_t temp_data[TEMP_BLOCK_SIZE];
    dt_sensor_data_nt *tdp;

    tdp = (dt_sensor_data_nt *) temp_data;
    tdp->data[0] = call Adc.readAdc();
    temp_state = TEMP_STATE_IDLE;
    call Adc.release();
    tdp->len = TEMP_BLOCK_SIZE;
    tdp->dtype = DT_SENSOR_DATA;
    tdp->id = SNS_ID_TEMP;
    tdp->sched_mis = 0;
    tdp->stamp_mis = 0;
    call Collect.collect(temp_data, TEMP_BLOCK_SIZE);
  }


  event void RegimeCtrl.regimeChange() {
    uint32_t new_period;

    call PeriodTimer.stop();
    if (call Adc.isOwner())
      call Adc.release();
    new_period = call RegimeCtrl.sensorPeriod(SNS_ID_TEMP);
    if (new_period == 0)
      temp_state = TEMP_STATE_OFF;
    else if (new_period != period) {
      temp_state = TEMP_STATE_IDLE;
      period = new_period;
      call PeriodTimer.startPeriodic(period);
    }
  }

  async command const mm3_sensor_config_t* AdcConfigure.getConfiguration() {
    return &temp_config;
  }
}
