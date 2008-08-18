/*
 * CradleP.nc: Handle docking functions
 * Copyright 2008 Eric B. Decker
 * All rights reserved.
 *
 * Cradle Monitor Sensor Driver
 * @author: Eric B. Decker
 *
 * Detect and handle docking (in the cradle).
 *
 * When docked we want to do:
 *
 * 1) switch comm functions from radio based to serial based.
 * 2) Charge the battery
 * 3) Detect when we undock.
 *
 * Docking detection uses the battery sense circuit.  If we are docked
 * a voltage is applied on one of the external pins (used to charge the
 * battery too).  If we have the battery sense circuit turned off and run
 * a bettery sense cycle we can tell if we are docked or not.  If voltage
 * is present (over a certain threshold, 30000 counts (actually sees 45000+
 * vs. below like 0)) then we are docked.  Otherwise undocked.
 *
 * Dock detection utilizes battery sensing and so needs to arbritrate for
 * the ADC subsystem.  As such it makes sense to piggy back on battery
 * sensing.  However, battery sensing is under regime control and dock
 * sensing happens all the time when at the surface (or other set of parameters
 * that say docking is possible).  When the battery is cycling, check at
 * surface (dock_check) and piggy back another reading for the dock.  If the
 * battery isn't being sampled (regime says no), then run independently.
 *
 * When docked:
 *
 * 1) Will be charging the battery...   But this means that the Batt FET
 *    will be on.  Any batt measurement will read the current battery voltage
 *    and not give us an indication of being docked.
 *
 * 2) Should check periodically for docked status by turning off the
 *    Batt FET and doing a batt sense.
 *
 * When docked, other than the dock check is there a reason to be reading
 * the battery?
 *
 * How to piggie back...
 *
 * If batt is being sensed with period T_b....  Do we want dock sensing
 * to be some multiple of this?
 *
 * Could run seperate timers for dock and battery (current implementation
 * does this).  But then how to meld?  When one goes off it can check
 * to see how close the other is.  If within the turn on time of
 * the sensor would make sense to proceed.
 *
 * How often to write battery voltage?
 * How often to sense battery?  Want somekind of early warning of
 * loss of battery power so we can go into conserve mode.
 */

#include "sensors.h"
#include "cradle.h"

module CradleP {
  provides {
    interface StdControl;
    interface Init;
    interface AdcConfigure<const mm3_sensor_config_t*>;
    interface SenseVal;
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
    signal SenseVal.valAvail(cdp->data[0], cdp->stamp_mis);
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
