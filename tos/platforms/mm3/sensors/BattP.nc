/*
 * BattP.nc: implementation for Battery Monitor
 * Copyright 2008 Eric B. Decker
 * All rights reserved.
 */


/**
 *  Battery Monitor Sensor Driver
 *  @author: Eric B. Decker
 */

#include "sensors.h"
#include "sd_blocks.h"

module BattP {
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
  uint8_t  batt_state;
  uint32_t err_overruns;


  command error_t Init.init() {
    batt_state = SNS_STATE_OFF;
    err_overruns = 0;
    return SUCCESS;
  }


  command error_t StdControl.start() {
    period = call RegimeCtrl.sensorPeriod(SNS_ID_BATT);
    if (period) {
      call PeriodTimer.startPeriodic(period);
      batt_state = SNS_STATE_PERIOD_WAIT;
    } else
      batt_state = SNS_STATE_OFF;
    return SUCCESS;
  }


  command error_t StdControl.stop() {
    call PeriodTimer.stop();
    if (batt_state == SNS_STATE_PERIOD_WAIT)
      batt_state = SNS_STATE_OFF;
  }


  event void PeriodTimer.fired() {
    if (batt_state != SNS_STATE_PERIOD_WAIT) {
      err_overruns++;
      /*
       * bitch, shouldn't be here.  Of course it could be
       * because something took way too long.
       */
      call StdControl.start();
      return;
    }
    batt_state = SNS_STATE_ADC_WAIT;
    call Adc.reqConfigure();
  }


  event void Adc.configured() {
    uint16_t data;
    dt_sensor_data_nt batt_data;

    data = call Adc.readAdc();
    batt_state = SNS_STATE_PERIOD_WAIT;
    call Adc.release();
    batt_data.len = BATT_BLOCK_SIZE;
    batt_data.dtype = DT_SENSOR_DATA;
    batt_data.id = SNS_ID_BATT;
    batt_data.sched_epoch = 0;
    batt_data.sched_mis = 0;
    batt_data.stamp_epoch = 0;
    batt_data.stamp_mis = 0;
    batt_data.data[0] = data;
    call Collect.collect((uint8_t *)(&batt_data), BATT_BLOCK_SIZE);
  }


  event void RegimeCtrl.regimeChange() {
    uint32_t new_period;

    new_period = call RegimeCtrl.sensorPeriod(SNS_ID_BATT);
    if (new_period == 0) {
      call PeriodTimer.stop();
      if (batt_state == SNS_STATE_PERIOD_WAIT)
	batt_state = SNS_STATE_OFF;
    } else if (new_period != period) {
      period = new_period;
      call PeriodTimer.stop();
      call PeriodTimer.startPeriodic(period);
      /* leave state alone */
    }
  }


  const mm3_sensor_config_t batt_config =
    { .sns_id = SNS_ID_BATT,
      .mux  = SMUX_BATT,
      .t_settle = 164,           /* ~ 5mS */
      .gmux = 0,
    };

  async command const mm3_sensor_config_t* AdcConfigure.getConfiguration() {
    return &batt_config;
  }
}
