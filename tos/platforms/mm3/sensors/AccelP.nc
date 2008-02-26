/* 
 * AccelP.nc: implementation for accelerometer
 * Copyright 2008 Eric B. Decker
 * All rights reserved.
 */


/**
 *  Accel Sensor Driver
 *  @author: Eric B. Decker
 *
 * The accelerometer is a single device with 3 outputs, one
 * for each axis.  There are three different SMUX settings
 * for reading each access.
 *
 * The sensor is powered up and the X axis selected by the
 * ADC subsystem.  The accel driver after being granted
 * reads the X data, switches to Y (smux change), and delays
 * to allow settling time for the smux switch.  This is
 * repeated for the Z access.
 */

#include "sensors.h"

module AccelP {
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
  uint8_t  accel_state;
  uint32_t err_overruns;


  command error_t Init.init() {
    accel_state = SNS_STATE_OFF;
    err_overruns = 0;
    return SUCCESS;
  }


  command error_t StdControl.start() {
    period = call RegimeCtrl.sensorPeriod(SNS_ID_ACCEL);
    if (period) {
      call PeriodTimer.startPeriodic(period);
      accel_state = SNS_STATE_PERIOD_WAIT;
    } else
      accel_state = SNS_STATE_OFF;
    return SUCCESS;
  }


  command error_t StdControl.stop() {
    call PeriodTimer.stop();
    if (accel_state == SNS_STATE_PERIOD_WAIT)
      accel_state = SNS_STATE_OFF;
  }


  event void PeriodTimer.fired() {
    if (accel_state != SNS_STATE_PERIOD_WAIT) {
      err_overruns++;
      /*
       * bitch, shouldn't be here.  Of course it could be
       * because something took way too long.
       */
      call StdControl.start();
      return;
    }
    accel_state = SNS_STATE_ADC_WAIT;
    call Adc.request();
  }


  event void Adc.granted() {
    uint16_t data;

    data = call Adc.readAdc();
    accel_state = SNS_STATE_PERIOD_WAIT;
    call Adc.release();
  }


  event void RegimeCtrl.regimeChange() {
    uint32_t new_period;

    new_period = call RegimeCtrl.sensorPeriod(SNS_ID_ACCEL);
    if (new_period == 0) {
      call PeriodTimer.stop();
      if (accel_state == SNS_STATE_PERIOD_WAIT)
	accel_state = SNS_STATE_OFF;
    } else if (new_period != period) {
      period = new_period;
      call PeriodTimer.stop();
      call PeriodTimer.startPeriodic(period);
      /* leave state alone */
    }
  }


  const mm3_sensor_config_t accel_config =
    { .sns_id = SNS_ID_ACCEL,
      .mux  = SMUX_ACCEL_X,
      .gmux = 0,
      .t_powerup = 5
    };


    async command const mm3_sensor_config_t* AdcConfigure.getConfiguration() {
      return &accel_config;
    }
}
