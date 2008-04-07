/* 
 * PressP.nc: implementation for Pressure (differential)
 * Copyright 2008 Eric B. Decker
 * All rights reserved.
 */


/**
 *  Pressure Sensor Driver
 *  @author: Eric B. Decker
 */

#include "sensors.h"
#include "press.h"

module PressP {
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
  uint8_t  press_state;
  uint32_t err_overruns;
  uint32_t err_eaves_drops;
  bool     eaves_busy;


  command error_t Init.init() {
    period = 0;
    press_state = PRESS_STATE_OFF;
    err_overruns = 0;
    return SUCCESS;
  }


  command error_t StdControl.start() {
    call HW.press_on();
    return SUCCESS;
  }


  command error_t StdControl.stop() {
    call HW.press_off();
    return SUCCESS;
  }


  event void PeriodTimer.fired() {
    if (press_state != PRESS_STATE_IDLE) {
      err_overruns++;
      /*
       * bitch, shouldn't be here.  Of course it could be because something took way too long.
       */
//      call Panic.brk();
      return;
    }
    press_state = PRESS_STATE_READ;
    call Adc.reqConfigure();
  }


  event void Adc.configured() {
    uint8_t press_data[PRESS_BLOCK_SIZE];
    dt_sensor_data_nt *pdp;

    pdp = (dt_sensor_data_nt *) press_data;
    pdp->data[0] = call Adc.readAdc();
    press_state = PRESS_STATE_IDLE;
    call Adc.release();
    pdp->len = PRESS_BLOCK_SIZE;
    pdp->dtype = DT_SENSOR_DATA;
    pdp->id = SNS_ID_PRESS;
    pdp->sched_mis = call PeriodTimer.gett0();
    pdp->stamp_mis = call PeriodTimer.getNow();
    if (call mm3Control.eavesdrop()) {
      if (eaves_busy)
	err_eaves_drops++;
      else {
	if (call mm3CommData.send_data(pdp, PRESS_BLOCK_SIZE))
	  err_eaves_drops++;
	else
	  eaves_busy = TRUE;
      }
    }
    call Collect.collect(press_data, PRESS_BLOCK_SIZE);
  }


  event void mm3CommData.send_data_done(error_t rtn) {
    eaves_busy = FALSE;
  }

  event void RegimeCtrl.regimeChange() {
    uint32_t new_period;

    call PeriodTimer.stop();
    if (call Adc.isOwner())
      call Adc.release();
    new_period = call RegimeCtrl.sensorPeriod(SNS_ID_PRESS);
    if (new_period == 0)
      press_state = PRESS_STATE_OFF;
    else if (new_period != period) {
      press_state = PRESS_STATE_IDLE;
      period = new_period;
      call PeriodTimer.startPeriodic(period);
    }
  }


  async command const mm3_sensor_config_t* AdcConfigure.getConfiguration() {
    return &press_config;
  }
}
