/* 
 * SalP.nc: implementation for salinity
 * Copyright 2008 Eric B. Decker
 * All rights reserved.
 */


/**
 *  Salinity Sensor Driver
 *  @author: Eric B. Decker
 */

#include "sensors.h"
#include "sal.h"

module SalP {
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
    interface HplMM3Adc as HW;
  }
}

implementation {
  uint32_t period;
  uint8_t  sal_state;
  uint32_t err_overruns;

  uint16_t data[2];

  command error_t Init.init() {
    period = 0;
    sal_state = SAL_STATE_OFF;
    err_overruns = 0;
    return SUCCESS;
  }

  command error_t StdControl.start() {
    /* power up Sal */
    return SUCCESS;
  }

  command error_t StdControl.stop() {
    /* power down Sal */
    return SUCCESS;
  }

  event void PeriodTimer.fired() {
    if (sal_state != SAL_STATE_IDLE) {
      err_overruns++;
      /*
       * bitch, shouldn't be here.  Of course it could be
       * because something took way too long.
       */
      return;
    }
    sal_state = SAL_STATE_READ_1;
    call Adc.reqConfigure();
  }


  event void Adc.configured() {
    uint8_t sal_data[SAL_BLOCK_SIZE];
    dt_sensor_data_nt *sdp;

    switch(sal_state) {
      case SAL_STATE_READ_1:
	data[0] = call Adc.readAdc();
	call HW.toggleSal();
	sal_state = SAL_STATE_READ_2;
	call Adc.reconfigure(&sal_config_2);
	return;

      case SAL_STATE_READ_2:
	data[1] = call Adc.readAdc();
	sal_state = SAL_STATE_IDLE;
	call Adc.release();
	break;

      default:
	return;
    }

    sdp = (dt_sensor_data_nt *) sal_data;
    sdp->len = SAL_BLOCK_SIZE;
    sdp->dtype = DT_SENSOR_DATA;
    sdp->id = SNS_ID_SAL;
    sdp->sched_epoch = 0;
    sdp->sched_mis = 0;
    sdp->stamp_epoch = 0;
    sdp->stamp_mis = 0;
    sdp->data[0] = data[0];
    sdp->data[1] = data[1];
    call Collect.collect(sal_data, SAL_BLOCK_SIZE);
  }


  event void RegimeCtrl.regimeChange() {
    uint32_t new_period;

    call PeriodTimer.stop();
    if (call Adc.isOwner())
      call Adc.release();
    new_period = call RegimeCtrl.sensorPeriod(SNS_ID_SAL);
    if (new_period == 0)
      sal_state = SAL_STATE_OFF;
    else if (new_period != period) {
      sal_state = SAL_STATE_IDLE;
      period = new_period;
      call PeriodTimer.startPeriodic(period);
    }
  }


  async command const mm3_sensor_config_t* AdcConfigure.getConfiguration() {
    return &sal_config_1;
  }
}
