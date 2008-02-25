/* -*- mode:c; indent-tabs-mode: nil; c-basic-offset: 2 -*-
/* 
 * mm3SalP.nc: implementation for salinity
 * Copyright 2008 Eric B. Decker
 * All rights reserved.
 */


/**
 *  Salinity Sensor Driver
 *  @author: Eric B. Decker
 */

#include "sensors.h"

module mm3SalP {
  provides {
    interface StdControl;
    interface Init;
    interface AdcConfigure<const mm3_sensor_config_t*>;
  }

  uses {
    interface mm3Regime as RegimeCtrl;
    interface Timer<TMilli> as PeriodTimer;
    interface mm3Adc as Adc;
    interface HplMM3Adc as HW;
  }
}
implementation {
  uint32_t period;
  uint8_t  sal_state;
  uint32_t err_overruns;


  command error_t Init.init() {
    sal_state = SNS_STATE_OFF;
    err_overruns = 0;
    return SUCCESS;
  }


  command error_t StdControl.start() {
    period = call RegimeCtrl.sensorPeriod(SNS_ID_SAL);
    if (period) {
      call PeriodTimer.startPeriodic(period);
      sal_state = SNS_STATE_PERIOD_WAIT;
    } else
      sal_state = SNS_STATE_OFF;
    return SUCCESS;
  }


  command error_t StdControl.stop() {
    call PeriodTimer.stop();
    if (sal_state == SNS_STATE_PERIOD_WAIT)
      sal_state = SNS_STATE_OFF;
  }


  event void PeriodTimer.fired() {
    if (sal_state != SNS_STATE_PERIOD_WAIT) {
      err_overruns++;
      /*
       * bitch, shouldn't be here.  Of course it could be
       * because something took way too long.
       */
      call StdControl.start();
      return;
    }
    sal_state = SNS_STATE_ADC_WAIT;
    call Adc.request();
  }


  event void Adc.granted() {
    uint16_t data;

    data = call Adc.readAdc();
    call HW.toggleSal();
    sal_state = SNS_STATE_PERIOD_WAIT;
    call Adc.release();
  }


  event void RegimeCtrl.regimeChange() {
    uint32_t new_period;

    new_period = call RegimeCtrl.sensorPeriod(SNS_ID_SAL);
    if (new_period == 0) {
      call PeriodTimer.stop();
      if (sal_state == SNS_STATE_PERIOD_WAIT)
	sal_state = SNS_STATE_OFF;
    } else if (new_period != period) {
      period = new_period;
      call PeriodTimer.stop();
      call PeriodTimer.startPeriodic(period);
      /* leave state alone */
    }
  }


  const mm3_sensor_config_t sal_config =
    { .sns_id = SNS_ID_SAL,
      .mux  = SMUX_SALINITY,
      .gmux = 0,
      .t_powerup = 5
    };


    async command const mm3_sensor_config_t* AdcConfigure.getConfiguration() {
      return &sal_config;
    }
}
