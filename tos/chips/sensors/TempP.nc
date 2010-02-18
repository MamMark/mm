/* 
 * TempP.nc: implementation for temperature
 * Copyright 2008, 2010 Eric B. Decker
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
    interface AdcConfigure<const mm_sensor_config_t*>;
  }

  uses {
    interface Regime as RegimeCtrl;
    interface Timer<TMilli> as PeriodTimer;
    interface Adc;
    interface Collect;
    interface Hpl_MM_hw as HW;
    interface mmControl;
    interface mmCommData;
    interface Panic;
  }
}

implementation {
  uint32_t period;
  uint8_t  temp_state;
  uint32_t err_overruns;
  uint32_t err_eaves_drops;


  command error_t Init.init() {
    period = 0;
    temp_state = TEMP_STATE_OFF;
    err_overruns = 0;
    return SUCCESS;
  }


  command error_t StdControl.start() {
    call HW.temp_on();
    return SUCCESS;
  }


  command error_t StdControl.stop() {
    call HW.temp_off();
    return SUCCESS;
  }


  event void PeriodTimer.fired() {
    if (temp_state != TEMP_STATE_IDLE) {
      err_overruns++;
      /*
       * bitch, shouldn't be here.  Of course it could be
       * because something took way too long.
       */
//      call Panic.brk();
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
    tdp->sns_id = SNS_ID_TEMP;
    tdp->sched_mis = call PeriodTimer.gett0();
    tdp->stamp_mis = call PeriodTimer.getNow();
    if (call mmControl.eavesdrop()) {
      if (call mmCommData.send_data(tdp, TEMP_BLOCK_SIZE))
	err_eaves_drops++;
    }
    call Collect.collect(temp_data, TEMP_BLOCK_SIZE);
  }


  event void mmCommData.send_data_done(error_t rtn) {
  }

  event void RegimeCtrl.regimeChange() {
    uint32_t new_period;

    call PeriodTimer.stop();
    if (call Adc.isOwner())
      call Adc.release();
    new_period = call RegimeCtrl.sensorPeriod(SNS_ID_TEMP);
    if (new_period == 0) {
      temp_state = TEMP_STATE_OFF;
      return;
    }
    temp_state = TEMP_STATE_IDLE;
    period = new_period;
    call PeriodTimer.startPeriodic(period);
  }

  async command const mm_sensor_config_t* AdcConfigure.getConfiguration() {
    return &temp_config;
  }
}
