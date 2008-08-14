/*
 * CradleP.nc: Are we plugged into the cradle
 * Copyright 2008 Eric B. Decker
 * All rights reserved.
 */


/**
 *  Cradle Monitor Sensor Driver
 *  @author: Eric B. Decker
 *
 * Detecting being plugged into the cradle uses the battery sensor hardware so
 * we are forced to go through the ADC/sensor system.
 *
 * It is just like the battery sensor with the following differences:
 *
 * 1) Cradle sensing doesn't turn on the battery fet.  If a voltage is present
 *    (adc is used to read) then we are in the cradle.
 *
 * 2) The cradle sensor always runs.  It doesn't pay attention to the entry in
 *    regime control.  We can change this and make use of the entry to tailor
 *    how often the cradle connect is looked at.
 */

#include "sensors.h"
#include "cradle.h"

module CradleP {
  provides {
    interface StdControl;
    interface Init;
    interface AdcConfigure<const mm3_sensor_config_t*>;
  }

  uses {
    interface Regime as RegimeCtrl;
    interface Timer<TMilli> as PeriodTimer;
    interface Adc;
    interface HplMM3Adc as HW;
    interface mm3CommData;
    interface Panic;
  }
}

implementation {
  uint8_t  cradle_state;
  uint32_t err_overruns;
  bool     docked;
  bool     comm_idle;


  command error_t Init.init() {
    cradle_state = CRADLE_STATE_OFF;
    err_overruns = 0;
    docked = FALSE;
    comm_idle = TRUE;
    return SUCCESS;
  }


  command error_t StdControl.start() {
    /*
     * sensing being in the cradle (docked) is done by reading the battery
     * but without switching the battery fet on.  If we are in the cradle
     * then we will see the charging voltage.
     *
     * call HW.batt_on();
     *
     * So we don't need to do anything when starting and stopping.
     */
    nop();
    return SUCCESS;
  }


  command error_t StdControl.stop() {
    nop();
    return SUCCESS;
  }


  event void PeriodTimer.fired() {
    if (cradle_state != CRADLE_STATE_IDLE) {
      err_overruns++;
      /*
       * bitch, shouldn't be here.  Of course it could be
       * because something took way too long.
       */
//      call Panic.brk();
      return;
    }
    cradle_state = CRADLE_STATE_READ;
    call Adc.reqConfigure();
  }


  event void Adc.configured() {
    uint8_t cradle_data[BATT_BLOCK_SIZE];
    dt_sensor_data_nt *cdp;

    cdp = (dt_sensor_data_nt *) cradle_data;
    cdp->data[0] = call Adc.readAdc();
    cradle_state = CRADLE_STATE_IDLE;
    call Adc.release();
    cdp->len = BATT_BLOCK_SIZE;
    cdp->dtype = DT_SENSOR_DATA;
    cdp->sns_id = SNS_ID_CRADLE;
    cdp->sched_mis = call PeriodTimer.gett0();
    cdp->stamp_mis = call PeriodTimer.getNow();
    if (comm_idle)
      if (call mm3CommData.send_data(cdp, BATT_BLOCK_SIZE) == SUCCESS)
	comm_idle = FALSE;
  }


  event void mm3CommData.send_data_done(error_t rtn) {
    comm_idle = TRUE;
  }


  event void RegimeCtrl.regimeChange() {
    call PeriodTimer.stop();
    if (call Adc.isOwner())
      call Adc.release();
    cradle_state = CRADLE_STATE_IDLE;
    call PeriodTimer.startPeriodic(CRADLE_PERIOD);
  }


  async command const mm3_sensor_config_t* AdcConfigure.getConfiguration() {
    return &cradle_config;
  }
}
