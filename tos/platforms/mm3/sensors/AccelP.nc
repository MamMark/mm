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
 * repeated for the Z axis.
 */

#include "sensors.h"
#include "accel.h"

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
    interface HplMM3Adc as HW;
    interface Panic;
    interface mm3Control;
  }
}

implementation {
  uint32_t period;
  uint8_t  accel_state;
  uint32_t err_overruns;
  
  uint16_t data[3];

  command error_t Init.init() {
    period = 0;
    accel_state = ACCEL_STATE_OFF;
    err_overruns = 0;
    return SUCCESS;
  }

  command error_t StdControl.start() {
    call HW.accel_on();
    return SUCCESS;
  }

  command error_t StdControl.stop() {
    call HW.accel_off();
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
    uint8_t accel_data[ACCEL_BLOCK_SIZE];
    dt_sensor_data_nt *adp;
    uint32_t temp;
    uint16_t i;

    temp = 0;
    switch(accel_state) {
      case ACCEL_STATE_READ_X:
	for (i = 0; i < ACCEL_SAMPLES; i++)
	  temp += call Adc.readAdc();
	data[0] = temp/ACCEL_SAMPLES;
	accel_state = ACCEL_STATE_READ_Y;
	call Adc.reconfigure(&accel_config_Y);
	return;

      case ACCEL_STATE_READ_Y:
	for (i = 0; i < ACCEL_SAMPLES; i++)
	  temp += call Adc.readAdc();
	data[1] = temp/ACCEL_SAMPLES;
	accel_state = ACCEL_STATE_READ_Z;
	call Adc.reconfigure(&accel_config_Z);
	return;

      case ACCEL_STATE_READ_Z:
	for (i = 0; i < ACCEL_SAMPLES; i++)
	  temp += call Adc.readAdc();
	data[2] = temp/ACCEL_SAMPLES;
	accel_state = ACCEL_STATE_IDLE;
	call Adc.release();
	break;

      default:
	return;
    }

//    adp = call mm3Comm.getmsgbuf(ACCEL_BLOCK_SIZE);
    adp = (dt_sensor_data_nt *) accel_data;
    adp->len = ACCEL_BLOCK_SIZE;
    adp->dtype = DT_SENSOR_DATA;
    adp->id = SNS_ID_ACCEL;
    adp->sched_mis = call PeriodTimer.gett0();
    adp->stamp_mis = call PeriodTimer.getNow();
    adp->data[0] = data[0];
    adp->data[1] = data[1];
    adp->data[2] = data[2];
    if (call mm3Control.eavesdrop(SNS_ID_ACCEL)) {
//      call Panic.brk();
    }
    call Collect.collect(accel_data, ACCEL_BLOCK_SIZE);
  }


  event void RegimeCtrl.regimeChange() {
    uint32_t new_period;

    call PeriodTimer.stop();
    if (call Adc.isOwner())
      call Adc.release();
    new_period = call RegimeCtrl.sensorPeriod(SNS_ID_ACCEL);
    if (new_period == 0)
      accel_state = ACCEL_STATE_OFF;
    else if (new_period != period) {
      accel_state = ACCEL_STATE_IDLE;
      period = new_period;
      call PeriodTimer.startPeriodic(period);
    }
  }


  async command const mm3_sensor_config_t* AdcConfigure.getConfiguration() {
    return &accel_config_X;
  }
}
