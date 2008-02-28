/* 
 * SpeedP.nc: implementation for Speed
 * Copyright 2008 Eric B. Decker
 * All rights reserved.
 */


/**
 *  Speed Sensor Driver
 *  @author: Eric B. Decker
 */

#include "sensors.h"

module SpeedP {
  provides {
    interface StdControl;
    interface Init;
    interface AdcConfigure<const mm3_sensor_config_t*>;
  }

  uses {
    interface Regime as RegimeCtrl;
    interface Timer<TMilli> as PeriodTimer;
    interface Adc;
  }
}
implementation {
  uint32_t period;
  uint8_t  speed_state;
  uint32_t err_overruns;


  command error_t Init.init() {
    speed_state = SNS_STATE_OFF;
    err_overruns = 0;
    return SUCCESS;
  }


  command error_t StdControl.start() {
    period = call RegimeCtrl.sensorPeriod(SNS_ID_SPEED);
    if (period) {
      call PeriodTimer.startPeriodic(period);
      speed_state = SNS_STATE_PERIOD_WAIT;
    } else
      speed_state = SNS_STATE_OFF;
    return SUCCESS;
  }


  command error_t StdControl.stop() {
    call PeriodTimer.stop();
    if (speed_state == SNS_STATE_PERIOD_WAIT)
      speed_state = SNS_STATE_OFF;
  }


  event void PeriodTimer.fired() {
    if (speed_state != SNS_STATE_PERIOD_WAIT) {
      err_overruns++;
      /*
       * bitch, shouldn't be here.  Of course it could be
       * because something took way too long.
       */
      call StdControl.start();
      return;
    }
    speed_state = SNS_STATE_ADC_WAIT;
    call Adc.reqConfigure();
  }


  event void Adc.configured() {
    uint16_t data;

    data = call Adc.readAdc();
    speed_state = SNS_STATE_PERIOD_WAIT;
    call Adc.release();
  }


  event void RegimeCtrl.regimeChange() {
    uint32_t new_period;

    new_period = call RegimeCtrl.sensorPeriod(SNS_ID_SPEED);
    if (new_period == 0) {
      call PeriodTimer.stop();
      if (speed_state == SNS_STATE_PERIOD_WAIT)
	speed_state = SNS_STATE_OFF;
    } else if (new_period != period) {
      period = new_period;
      call PeriodTimer.stop();
      call PeriodTimer.startPeriodic(period);
      /* leave state alone */
    }
  }


  const mm3_sensor_config_t speed_config_1 =
    { .sns_id = SNS_ID_SPEED,
      .mux  = DMUX_SPEED_1,
      .t_settle = 164,          /* ~ 5mS */
      .gmux = GMUX_x400,
    };


  const mm3_sensor_config_t speed_config_2 =
    { .sns_id = SNS_ID_SPEED,
      .mux  = DMUX_SPEED_2,
      .t_settle = 4,		/* ~ 120 uS */
      .gmux = GMUX_x400,
    };


  async command const mm3_sensor_config_t* AdcConfigure.getConfiguration() {
    return &speed_config_1;
  }
}
