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
#include "speed.h"

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
    interface Collect;
    interface HplMM3Adc as HW;
    interface mm3Control;
    interface mm3CommData;
    interface Panic;
  }
}

implementation {
  uint32_t period;
  uint8_t  speed_state;
  uint32_t err_overruns;
  uint32_t err_eaves_drops;
  bool     eaves_busy;
  
  uint16_t data[2];

  command error_t Init.init() {
    period = 0;
    speed_state = SPEED_STATE_OFF;
    err_overruns = 0;
    return SUCCESS;
  }

  command error_t StdControl.start() {
    call HW.speed_on();
    return SUCCESS;
  }

  command error_t StdControl.stop() {
    call HW.speed_off();
    return SUCCESS;
  }

  event void PeriodTimer.fired() {
    if (speed_state != SPEED_STATE_IDLE) {
      err_overruns++;
      /*
       * bitch, shouldn't be here.  Of course it could be
       * because something took way too long.
       */
//      call Panic.brk();
      return;
    }
    speed_state = SPEED_STATE_READ_1;
    call Adc.reqConfigure();
  }


  event void Adc.configured() {
    uint8_t speed_data[SPEED_BLOCK_SIZE];
    dt_sensor_data_nt *sdp;

    switch(speed_state) {
      case SPEED_STATE_READ_1:
	data[0] = call Adc.readAdc();
	speed_state = SPEED_STATE_READ_2;
	call Adc.reconfigure(&speed_config_2);
	return;

      case SPEED_STATE_READ_2:
	data[1] = call Adc.readAdc();
	speed_state = SPEED_STATE_IDLE;
	call Adc.release();
	break;

      default:
	return;
    }

    sdp = (dt_sensor_data_nt *) speed_data;
    sdp->len = SPEED_BLOCK_SIZE;
    sdp->dtype = DT_SENSOR_DATA;
    sdp->id = SNS_ID_SPEED;
    sdp->sched_mis = call PeriodTimer.gett0();
    sdp->stamp_mis = call PeriodTimer.getNow();
    sdp->data[0] = data[0];
    sdp->data[1] = data[1];
    if (call mm3Control.eavesdrop()) {
      if (eaves_busy)
	err_eaves_drops++;
      else {
	if (call mm3CommData.send_data(sdp, SPEED_BLOCK_SIZE))
	  err_eaves_drops++;
	else
	  eaves_busy = TRUE;
      }
    }
    call Collect.collect(speed_data, SPEED_BLOCK_SIZE);
  }


  event void mm3CommData.send_data_done(error_t rtn) {
    eaves_busy = FALSE;
  }

  event void RegimeCtrl.regimeChange() {
    uint32_t new_period;

    call PeriodTimer.stop();
    if (call Adc.isOwner())
      call Adc.release();
    new_period = call RegimeCtrl.sensorPeriod(SNS_ID_SPEED);
    if (new_period == 0)
      speed_state = SPEED_STATE_OFF;
    else if (new_period != period) {
      speed_state = SPEED_STATE_IDLE;
      period = new_period;
      call PeriodTimer.startPeriodic(period);
    }
  }

  async command const mm3_sensor_config_t* AdcConfigure.getConfiguration() {
    return &speed_config_1;
  }
}
