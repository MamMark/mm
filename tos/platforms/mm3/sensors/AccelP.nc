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
    interface Collect;
    interface Leds;
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
    call Leds.led1Toggle();
    accel_state = SNS_STATE_ADC_WAIT;
    call Adc.reqConfigure();
  }


  uint16_t data[3];
  const mm3_sensor_config_t accel_config_Y;
  const mm3_sensor_config_t accel_config_Z;

  event void Adc.configured() {
    dt_sensor_data_nt accel_data;

    switch(accel_state) {
      case SNS_STATE_ADC_WAIT:
	data[0] = call Adc.readAdc();
	accel_state = SNS_STATE_PART_2_WAIT;
	call Adc.reconfigure(&accel_config_Y);
	return;

      case SNS_STATE_PART_2_WAIT:
	data[1] = call Adc.readAdc();
	accel_state = SNS_STATE_PART_3_WAIT;
	call Adc.reconfigure(&accel_config_Z);
	return;

      case SNS_STATE_PART_3_WAIT:
	data[2] = call Adc.readAdc();
	accel_state = SNS_STATE_PERIOD_WAIT;
	call Adc.release();
	break;

      default:
	/*
	 * oops.  shouldn't be here.  bitch
	 */
	return;
    }
    accel_data.len = ACCEL_BLOCK_SIZE;
    accel_data.dtype = DT_SENSOR_DATA;
    accel_data.id = SNS_ID_ACCEL;
    accel_data.sched_epoch = 0;
    accel_data.sched_mis = 0;
    accel_data.stamp_epoch = 0;
    accel_data.stamp_mis = 0;
    accel_data.data[0] = data[0];
    accel_data.data[1] = data[0];
    accel_data.data[2] = data[0];
    call Collect.collect((uint8_t *)(&accel_data), ACCEL_BLOCK_SIZE);
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


  /*
   * Accel is one device with 3 parts.  First X is used
   * and its settling time is used to power the device up
   * Once X is done the other two are sequenced to get
   * Y and Z.  Settling times are set to be a simple
   * smux change.
   */
  const mm3_sensor_config_t accel_config_X =
    { .sns_id = SNS_ID_ACCEL,
      .mux  = SMUX_ACCEL_X,
//      .t_settle = 164,          /* ~ 5mS */
      .t_settle = 4,          /* ~ 5mS */
      .gmux = 0,
    };

  const mm3_sensor_config_t accel_config_Y =
    { .sns_id = SNS_ID_ACCEL,
      .mux  = SMUX_ACCEL_Y,
      .t_settle = 4,            /* ~ 120 uS */
      .gmux = 0,
    };

  const mm3_sensor_config_t accel_config_Z =
    { .sns_id = SNS_ID_ACCEL,
      .mux  = SMUX_ACCEL_Z,
      .t_settle = 4,            /* ~ 120 uS */
      .gmux = 0,
    };


  async command const mm3_sensor_config_t* AdcConfigure.getConfiguration() {
    return &accel_config_X;
  }
}
