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
  
  uint16_t data[3];

  command error_t Init.init() {
    period = 0;
    accel_state = ACCEL_STATE_IDLE;
    err_overruns = 0;
    return SUCCESS;
  }

  command error_t StdControl.start() {
    //Put actual code for performing power control in here (i.e. which pins to toggle)
    return SUCCESS;
  }

  command error_t StdControl.stop() {
    //Put actual code for performing power control in here (i.e. which pins to toggle)
    return SUCCESS;
  }

  event void PeriodTimer.fired() {
    if (accel_state != ACCEL_STATE_IDLE) {
      err_overruns++;
      /*
       * bitch, shouldn't be here.  Of course it could be
       * because something took way too long.
       */
      return;
    }
    call Leds.led1Toggle();
    accel_state = ACCEL_STATE_READ_X;
    call Adc.reqConfigure();
  }

  event void Adc.configured() {
    dt_sensor_data_nt accel_data;  
  
    switch(accel_state) {
    case ACCEL_STATE_READ_X:
	  data[0] = call Adc.readAdc();
	  accel_state = ACCEL_STATE_READ_Y;
	  call Adc.reconfigure(&accel_config_Y);
	  return;

    case ACCEL_STATE_READ_Y:
	  data[1] = call Adc.readAdc();
	  accel_state = ACCEL_STATE_READ_Z;
	  call Adc.reconfigure(&accel_config_Z);
	  return;

    case ACCEL_STATE_READ_Z:
	  data[2] = call Adc.readAdc();
	  accel_state = ACCEL_STATE_IDLE;
	  call Adc.release();
	  break;

    default:
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
    accel_data.data[1] = data[1];
    accel_data.data[2] = data[2];
    call Collect.collect((uint8_t *)(&accel_data), ACCEL_BLOCK_SIZE);
  }

  event void RegimeCtrl.regimeChange() {
    uint32_t new_period;

    call PeriodTimer.stop();
    new_period = call RegimeCtrl.sensorPeriod(SNS_ID_ACCEL);
    if (new_period == 0) {
      accel_state = ACCEL_STATE_IDLE;
	  call Adc.release();
    } 
    else if (new_period != period) {
      period = new_period;
      call PeriodTimer.startPeriodic(period);
    }
  }

  async command const mm3_sensor_config_t* AdcConfigure.getConfiguration() {
    return &accel_config_X;
  }
}
