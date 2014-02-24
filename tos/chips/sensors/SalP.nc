/* 
 * SalP.nc: implementation for salinity/surface detector
 * Copyright 2008, 2010, 2014: Eric B. Decker
 * All rights reserved.
 *
 * Salinity Sensor Driver
 * @author: Eric B. Decker
 *
 * Salinity/Surface Sensor
 *
 * This sensor performs double duty.  First it is used to get
 * a reading of the salinity of the surrounding sea water.
 * Second it is used for surface detection.  It is assumed that
 * when we are completly out of the water the reading will be
 * 65535 or there abouts.  Sea water will be much different
 * than this and shorted will be 0.  What does fresh water
 * look like?
 *
 * What to do if the sensor has failed/shorted?   Normally the
 * surface state is used to tell the GPS to acquire.  Surface
 * -> acquire,   Submerged -> shutdown.   Probably need hysterisis.
 *
 * Would like to put Tag control over in mmControl and abstract
 * out the control functions.  Bury the semantics of control
 * in a different module then the sensing modules.  But that
 * means there needs to be a mechanism to pass sensor values
 * to the control module.  How does this work and how does the
 * control module mess with the timing.  There is sensor
 * timing controlled by the regime system.  There is also timing
 * that effects control, ie. Sal for surface detection, Batt for
 * docked detection.  Polling rates will be different than
 * what the sensor will normally be set for.
 *
 * This argues for a control path and a data path.  For the time
 * being, the control mechanism (minimum sensing period) is hard
 * coded.  The data path is implemented as a push via an event
 * signal.
 *
 * Data structures are initilized to zero by start up code.
 * Initial state is OFF (0).   Period 0.
 */

#include "sensors.h"
#include "sal.h"

module SalP {
  provides {
    interface StdControl;
    interface AdcConfigure<const mm_sensor_config_t*>;
    interface SenseVal;
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
  /*
   * These get initilized to zero on boot  (start up code prior to main).
   */
  uint32_t period;
  uint8_t  sal_state;
  uint32_t err_overruns;
  uint32_t err_eaves_drops;
  bool     record;

  /*
   * sal_data holds last reading and is made available to other modules
   * sal_stamp is a time stamp as when that reading was taken.
   * Stamp of 0 says nothing has happened yet.
   */
  uint16_t sal_data, temp_data[2];
  uint32_t sal_stamp;

  command error_t StdControl.start() {
    call HW.sal_on();
    return SUCCESS;
  }

  command error_t StdControl.stop() {
    call HW.sal_off();
    return SUCCESS;
  }

  event void PeriodTimer.fired() {
    if (sal_state != SAL_STATE_IDLE) {
      err_overruns++;
      return;
    }
    sal_state = SAL_STATE_READ_1;
    call Adc.reqConfigure();
  }


  event void Adc.configured() {
    uint8_t sal_block[SAL_BLOCK_SIZE];
    dt_sensor_data_nt *sdp;

    switch(sal_state) {
      case SAL_STATE_READ_1:
	temp_data[0] = call Adc.readAdc();
	call HW.toggleSal();
	sal_state = SAL_STATE_READ_2;
	call Adc.reconfigure(&sal_config_2);
	return;

      case SAL_STATE_READ_2:
	temp_data[1] = call Adc.readAdc();
	sal_state = SAL_STATE_IDLE;
	call Adc.release();
	break;

      default:
	return;
    }

    sdp = (dt_sensor_data_nt *) sal_block;
    sdp->len = SAL_BLOCK_SIZE;
    sdp->dtype = DT_SENSOR_DATA;
    sdp->sns_id = SNS_ID_SAL;
    sdp->sched_ms = call PeriodTimer.gett0();
    sal_stamp     = call PeriodTimer.getNow();
    sdp->stamp_ms = sal_stamp;
    sdp->data[0]  = temp_data[0];
    sal_data      = temp_data[1];
    sdp->data[1]  = sal_data;
    signal SenseVal.valAvail(sal_data, sal_stamp);
    if (call mmControl.eavesdrop()) {
      if (call DTSender.send(sdp, SAL_BLOCK_SIZE))
	err_eaves_drops++;
    }
    if (record)
      call Collect.collect(sal_block, SAL_BLOCK_SIZE);
  }


  event void DTSender.sendDone(error_t rtn) {
  }

  event void RegimeCtrl.regimeChange() {
    uint32_t new_period;

    call PeriodTimer.stop();
    if (call Adc.isOwner())
      call Adc.release();
    new_period = call RegimeCtrl.sensorPeriod(SNS_ID_SAL);
    if (new_period == 0) { 
      period = SAL_OFF_SAMPLE_RATE;
      record = FALSE;
    } else {
      period = new_period;
      record = TRUE;
    }
    sal_state = SAL_STATE_IDLE;
    call PeriodTimer.startPeriodic(period);
  }


  async command const mm_sensor_config_t* AdcConfigure.getConfiguration() {
    return &sal_config_1;
  }
}
