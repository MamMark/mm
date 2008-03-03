/* 
 * PTempP.nc: implementation for pressure temperature
 * Copyright 2008 Eric B. Decker
 * All rights reserved.
 */


/**
 *  Pressure temperature Sensor Driver
 *  @author: Eric B. Decker
 */

#include "sensors.h"
#include "ptemp.h"

module PTempP {
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
  uint8_t  ptemp_state;
  uint32_t err_overruns;


  command error_t Init.init() {
    period = 0;
    ptemp_state = PTEMP_STATE_OFF;
    err_overruns = 0;
    return SUCCESS;
  }

  command error_t StdControl.start() {
    /* ptemp power up */
    return SUCCESS;
  }


  command error_t StdControl.stop() {
    /* ptemp power down */
    return SUCCESS;
  }

  event void PeriodTimer.fired() {
    if (ptemp_state != PTEMP_STATE_IDLE) {
      err_overruns++;
      /*
       * bitch, shouldn't be here.  Of course it could be
       * because something took way too long.
       */
      return;
    }
    ptemp_state = PTEMP_STATE_READ;
    call Adc.reqConfigure();
  }


  event void Adc.configured() {
    uint8_t ptemp_data[PTEMP_BLOCK_SIZE];
    dt_sensor_data_nt *pdp;

    pdp = (dt_sensor_data_nt *) ptemp_data;
    pdp->data[0] = call Adc.readAdc();
    ptemp_state = PTEMP_STATE_IDLE;
    call Adc.release();

    pdp->len = PTEMP_BLOCK_SIZE;
    pdp->dtype = DT_SENSOR_DATA;
    pdp->id = SNS_ID_PTEMP;
    pdp->sched_epoch = 0;
    pdp->sched_mis = 0;
    pdp->stamp_epoch = 0;
    pdp->stamp_mis = 0;
    call Collect.collect(ptemp_data, PTEMP_BLOCK_SIZE);
  }


  event void RegimeCtrl.regimeChange() {
    uint32_t new_period;

    call PeriodTimer.stop();
    if (call Adc.isOwner())
      call Adc.release();
    new_period = call RegimeCtrl.sensorPeriod(SNS_ID_PTEMP);
    if (new_period == 0)
      ptemp_state = PTEMP_STATE_OFF;
    else if (new_period != period) {
      ptemp_state = PTEMP_STATE_IDLE;
      period = new_period;
      call PeriodTimer.startPeriodic(period);
    }
  }


  async command const mm3_sensor_config_t* AdcConfigure.getConfiguration() {
    return &ptemp_config;
  }
}
