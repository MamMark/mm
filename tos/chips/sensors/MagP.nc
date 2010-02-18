/* 
 * MagP.nc: implementation for Magnatometer
 * Copyright 2008 Eric B. Decker
 * All rights reserved.
 */


/**
 *  Magnatometer Sensor Driver
 *  @author: Eric B. Decker
 */

#include "sensors.h"
#include "mag.h"

module MagP {
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
  uint8_t  mag_state;
  uint32_t err_overruns;
  uint32_t err_eaves_drops;

  uint16_t data[3];


  command error_t Init.init() {
    period = 0;
    mag_state = MAG_STATE_OFF;
    err_overruns = 0;
    return SUCCESS;
  }


  command error_t StdControl.start() {
    call HW.mag_on();
    return SUCCESS;
  }


  command error_t StdControl.stop() {
    call HW.mag_off();
    return SUCCESS;
  }


  event void PeriodTimer.fired() {
    if (mag_state != MAG_STATE_IDLE) {
      err_overruns++;
      /*
       * bitch, shouldn't be here.  Of course it could be
       * because something took way too long.
       */
//      call Panic.brk();
      return;
    }
    mag_state = MAG_STATE_READ_XY_A;
    call Adc.reqConfigure();
  }


  event void Adc.configured() {
    uint8_t mag_data[MAG_BLOCK_SIZE];
    dt_sensor_data_nt *mdp;
  
    switch(mag_state) {
      case MAG_STATE_READ_XY_A:
	data[0] = call Adc.readAdc();
	mag_state = MAG_STATE_READ_XY_B;
	call Adc.reconfigure(&mag_config_XY_B);
	return;

      case MAG_STATE_READ_XY_B:
	data[1] = call Adc.readAdc();
	mag_state = MAG_STATE_READ_Z;
	call Adc.reconfigure(&mag_config_Z);
	return;

      case MAG_STATE_READ_Z:
	data[2] = call Adc.readAdc();
	mag_state = MAG_STATE_IDLE;
	call Adc.release();
	break;

      default:
	return;
    }

    mdp = (dt_sensor_data_nt *) mag_data;
    mdp->len = MAG_BLOCK_SIZE;
    mdp->dtype = DT_SENSOR_DATA;
    mdp->sns_id = SNS_ID_MAG;
    mdp->sched_mis = call PeriodTimer.gett0();
    mdp->stamp_mis = call PeriodTimer.getNow();
    mdp->data[0] = data[0];
    mdp->data[1] = data[1];
    mdp->data[2] = data[2];
    if (call mm3Control.eavesdrop()) {
      if (call mm3CommData.send_data(mdp, MAG_BLOCK_SIZE))
	err_eaves_drops++;
    }
    call Collect.collect(mag_data, MAG_BLOCK_SIZE);
  }


  event void mm3CommData.send_data_done(error_t rtn) {
  }

  event void RegimeCtrl.regimeChange() {
    uint32_t new_period;

    call PeriodTimer.stop();
    if (call Adc.isOwner())
      call Adc.release();
    new_period = call RegimeCtrl.sensorPeriod(SNS_ID_MAG);
    if (new_period == 0) {
      mag_state = MAG_STATE_OFF;
      return;
    }
    mag_state = MAG_STATE_IDLE;
    period = new_period;
    call PeriodTimer.startPeriodic(period);
  }


  async command const mm3_sensor_config_t* AdcConfigure.getConfiguration() {
    return &mag_config_XY_A;
  }
}
