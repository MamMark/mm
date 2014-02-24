/* 
 * PressP.nc: implementation for Pressure (differential)
 * Copyright 2008, 2010, 2014: Eric B. Decker
 * All rights reserved.
 */


/**
 *  Pressure Sensor Driver
 *  @author: Eric B. Decker
 *
 * Data structures are initilized to zero by start up code.
 * Initial state is OFF (0).   Period 0.
 */

#include "sensors.h"
#include "press.h"

module PressP {
  provides {
    interface StdControl;
    interface AdcConfigure<const mm_sensor_config_t*>;
  }

  uses {
    interface Regime as RegimeCtrl;
    interface Timer<TMilli> as PeriodTimer;
    interface Adc;
    interface Collect;
    interface Hpl_MM_hw as HW;
    interface mmControl;
    interface DTSender;
    interface Panic;
  }
}

implementation {
  uint32_t period;
  uint8_t  press_state;
  uint32_t err_overruns;
  uint32_t err_eaves_drops;


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
    pdp->sns_id = SNS_ID_PRESS;
    pdp->sched_ms = call PeriodTimer.gett0();
    pdp->stamp_ms = call PeriodTimer.getNow();
    if (call mmControl.eavesdrop()) {
      if (call DTSender.send(pdp, PRESS_BLOCK_SIZE))
	err_eaves_drops++;
    }
    call Collect.collect(press_data, PRESS_BLOCK_SIZE);
  }


  event void DTSender.sendDone(error_t rtn) {
  }

  event void RegimeCtrl.regimeChange() {
    uint32_t new_period;

    call PeriodTimer.stop();
    if (call Adc.isOwner())
      call Adc.release();
    new_period = call RegimeCtrl.sensorPeriod(SNS_ID_PRESS);
    if (new_period == 0) {
      press_state = PRESS_STATE_OFF;
      return;
    }
    press_state = PRESS_STATE_IDLE;
    period = new_period;
    call PeriodTimer.startPeriodic(period);
  }


  async command const mm_sensor_config_t* AdcConfigure.getConfiguration() {
    return &press_config;
  }
}
