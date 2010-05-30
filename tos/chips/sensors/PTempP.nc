/* 
 * PTempP.nc: implementation for pressure temperature
 * Copyright 2008, 2010 Eric B. Decker
 * All rights reserved.
 */


/**
 *  Pressure temperature Sensor Driver
 *  @author: Eric B. Decker
 *
 * Data structures are initilized to zero by start up code.
 * Initial state is OFF (0).   Period 0.
 */

#include "sensors.h"
#include "ptemp.h"

module PTempP {
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
    interface CommDT;
    interface Panic;
  }
}

implementation {
  uint32_t period;
  uint8_t  ptemp_state;
  uint32_t err_overruns;
  uint32_t err_eaves_drops;


  command error_t StdControl.start() {
    call HW.ptemp_on();
    return SUCCESS;
  }


  command error_t StdControl.stop() {
    call HW.ptemp_off();
    return SUCCESS;
  }

  event void PeriodTimer.fired() {
    if (ptemp_state != PTEMP_STATE_IDLE) {
      err_overruns++;
      /*
       * bitch, shouldn't be here.  Of course it could be
       * because something took way too long.
       */
//      call Panic.brk();
      return;
    }
    ptemp_state = PTEMP_STATE_READ;
    call Adc.reqConfigure();
  }


  event void Adc.configured() {
    uint8_t ptemp_data[PTEMP_BLOCK_SIZE];
    dt_sensor_data_nt *pdp;

    pdp = (dt_sensor_data_nt *) ptemp_data;
    pdp->data[0] = call Adc.readAdc();
    ptemp_state = PTEMP_STATE_IDLE;
    call Adc.release();

    pdp->len = PTEMP_BLOCK_SIZE;
    pdp->dtype = DT_SENSOR_DATA;
    pdp->sns_id = SNS_ID_PTEMP;
    pdp->sched_mis = call PeriodTimer.gett0();
    pdp->stamp_mis = call PeriodTimer.getNow();
    if (call mmControl.eavesdrop()) {
      if (call CommDT.send_data(pdp, PTEMP_BLOCK_SIZE))
	err_eaves_drops++;
    }
    call Collect.collect(ptemp_data, PTEMP_BLOCK_SIZE);
  }


  event void CommDT.send_data_done(error_t rtn) {
  }

  event void RegimeCtrl.regimeChange() {
    uint32_t new_period;

    call PeriodTimer.stop();
    if (call Adc.isOwner())
      call Adc.release();
    new_period = call RegimeCtrl.sensorPeriod(SNS_ID_PTEMP);
    if (new_period == 0) {
      ptemp_state = PTEMP_STATE_OFF;
      return;
    }
    ptemp_state = PTEMP_STATE_IDLE;
    period = new_period;
    call PeriodTimer.startPeriodic(period);
  }


  async command const mm_sensor_config_t* AdcConfigure.getConfiguration() {
    return &ptemp_config;
  }
}
