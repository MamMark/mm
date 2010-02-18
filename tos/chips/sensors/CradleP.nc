/*
 * CradleP.nc: Handle docking functions
 * Copyright 2008, 2010 Eric B. Decker
 * All rights reserved.
 *
 * Cradle Monitor Sensor Driver
 * @author: Eric B. Decker
 *
 * Detect and handle docking (in the cradle).
 *
 * This module is single purpose and unlike a regular sensor.
 * While a regular sensor's primary purpose is to get a value
 * and store it, some sensors can also signal values to other
 * parts of the system for control functions.
 *
 * This module, the cradle's only purpose is to detect docking
 * events and to signal those to the reset of the system.  It
 * is implemented as a sensor because it has to interface to the
 * hardware using the ADC susbystem.
 *
 * When docked we want to do:
 *
 * 1) switch comm functions from radio based to serial based.
 * 2) Charge the battery
 * 3) Detect when we undock.
 *
 * Docking detection uses the battery sense circuit.  If we are docked
 * a voltage is applied on one of the external pins (used to charge
 * the battery too).  If we have the battery FET turned off and run a
 * bettery sense cycle we can tell if we are docked or not.  If
 * voltage is present (over a certain threshold, 30000 counts
 * (actually sees 45000+ vs. below like 0)) then we are docked.
 * Otherwise undocked.
 *
 * Dock detection utilizes battery sensing and so needs to arbritrate for
 * the ADC subsystem.  As such it makes sense to piggy back on battery
 * sensing.  However, battery sensing is under regime control and dock
 * sensing happens all the time when at the surface (or other set of parameters
 * that say docking is possible).  When the battery is cycling, check at
 * surface (dock_check) and piggy back another reading for the dock.  If the
 * battery isn't being sampled (regime says no), then run independently.
 *
 * We use the independent implementation as opposed to the additional complexity
 * of a combined Cradle/Batt driver.
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
 * How often to write battery voltage?
 * How often to sense battery?  Want somekind of early warning of
 * loss of battery power so we can go into conserve mode.
 *
 * Do we need to build in debounce?  For now we just use what we
 * get.  Worst case is we will get a docked signal and then a second
 * (assuming we are looking every second) later undocked gets generated.
 * The system code should be written to handle this scenerio.
 */

#include "sensors.h"
#include "cradle.h"

module CradleP {
  provides {
    interface StdControl;
    interface Init;
    interface AdcConfigure<const mm_sensor_config_t*>;
    interface Docked;
  }

  uses {
    interface Regime as RegimeCtrl;
    interface Timer<TMilli> as PeriodTimer;
    interface Adc;
    interface Collect;
    interface Hpl_MM_hw as HW;
    interface mmCommData;
    interface Panic;
    interface LogEvent;
  }
}

implementation {
  uint8_t  cradle_state;
  uint32_t err_overruns;
  bool     docked;
  bool     comm_idle;


  command bool Docked.isDocked() {
    return docked;
  }


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
     *
     * So we don't need to do anything when starting and stopping.
     * FIXME.  Check to see if we are doing this right.
     */
    call HW.batt_off();
    return SUCCESS;
  }


  /*
   * We are done doing a dock check.  If docked go back to
   * charging the battery.
   */
  command error_t StdControl.stop() {
//
// what should this be?   FIXME
//    if (docked)
//      call HW.batt_on();
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


  /*
   * Check dock state by reading battery sensor.  Note:  Batt
   * FET is off so we should read the input voltage on the charge
   * pin.  If above threshold then we are docked.
   *
   * Currently we do NOT implement debounce.  If we see multiple
   * changes (below and above threshold) we will generate multiple
   * signals.
   *
   * We implement a simple debounce (is this necessary?)  Probably.
   * We look for the same value (above or below threshold) for successive
   * count samples.  Then we see if we should change state.
   */

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
//#ifdef notdef
    if (comm_idle)
      if (call mmCommData.send_data(cdp, BATT_BLOCK_SIZE) == SUCCESS)
	comm_idle = FALSE;
//#endif
    call Collect.collect(cradle_data, BATT_BLOCK_SIZE);

    /*
     * See if we should change dock state.  On the transition generate
     * a signal to anyone interested.
     */
    if (docked) {
      if (cdp->data[0] < CRADLE_THRESHOLD) {
	docked = FALSE;
	call LogEvent.logEvent(DT_EVENT_UNDOCKED,0);
	signal Docked.undocked();
      }
    } else {
      if (cdp->data[0] >= CRADLE_THRESHOLD) {
	docked = TRUE;
	call LogEvent.logEvent(DT_EVENT_DOCKED,0);
	signal Docked.docked();
      }
    }
  }


  event void mmCommData.send_data_done(error_t rtn) {
    comm_idle = TRUE;
  }


  event void RegimeCtrl.regimeChange() {
    call PeriodTimer.stop();
    if (call Adc.isOwner())
      call Adc.release();
    cradle_state = CRADLE_STATE_IDLE;
    call PeriodTimer.startPeriodic(CRADLE_PERIOD);
  }


  async command const mm_sensor_config_t* AdcConfigure.getConfiguration() {
    return &cradle_config;
  }
}
