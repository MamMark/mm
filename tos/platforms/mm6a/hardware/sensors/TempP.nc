/*
 * TempP.nc: implementation for temperature
 * Copyright 2008, 2010, 2014, 2019: Eric B. Decker
 * All rights reserved.
 */


/**
 *  Temperature Sensor Driver
 *  @author: Eric B. Decker
 *
 * Data structures are initilized to zero by start up code.
 * Initial state is OFF (0).   Period 0.
 *
 * This is a composite sensor made up of both internal and
 * external I2C temperature sensors.  They live on the same
 * bus, get powered up together, and then read sequentially.
 */

#include "regime_ids.h"
#include "sensor_ids.h"

module TempP {
  uses {
    interface Regime as RegimeCtrl;
    interface SimpleSensor<uint16_t> as TmpP;
    interface SimpleSensor<uint16_t> as TmpX;
    interface Timer<TMilli> as PeriodTimer;
    interface Collect;
  }
}

implementation {
  typedef enum {
    TEMP_STATE_OFF              = 0,
    TEMP_STATE_POWERING_UP      = 1,
    TEMP_STATE_ON               = 2,
  } temp_state_t;

  uint32_t period;
  temp_state_t  temp_state;
  uint32_t err_overruns;

  void collect_tmps() {
    uint16_t data[2];                   /* 0 - I, 1 - X */
    dt_sensor_data_t td;

    data[0] = data[1] = 0;
    if (call TmpP.isPresent())
      call TmpP.read(&data[0]);
    if (call TmpX.isPresent())
      call TmpX.read(&data[1]);
    call TmpP.pwrDown();
    temp_state = TEMP_STATE_OFF;

    td.len = sizeof(td) + sizeof(data);
    td.dtype = DT_SENSOR_DATA;
    td.sched_delta = call PeriodTimer.getNow() - call PeriodTimer.gett0();
    td.sns_id = SNS_ID_TEMP_PX;
    call Collect.collect((void *) &td, sizeof(td),
                         (void *) &data, sizeof(data));
  }


  event void PeriodTimer.fired() {
    if (call TmpP.isPwrOn()) {
      /*
       * if power is already on, we must have overrun,
       * that is we didn't get to reading the last cycle.
       *
       * bitch.
       */
      err_overruns++;
      collect_tmps();
      return;
    }
    call TmpP.pwrUp();
    temp_state = TEMP_STATE_POWERING_UP;
  }


  event void TmpP.pwrUpDone(error_t error) {
    if (error != SUCCESS) {
      call TmpP.pwrDown();
      temp_state = TEMP_STATE_OFF;
      return;
    }
    temp_state = TEMP_STATE_ON;
    collect_tmps();
  }


  event void RegimeCtrl.regimeChange() {
    uint32_t new_period;

    call TmpP.pwrDown();
    temp_state = TEMP_STATE_OFF;
    call PeriodTimer.stop();
    new_period = call RegimeCtrl.sensorPeriod(RGM_ID_TEMP_PX);
    if (new_period == 0) {
      return;
    }
    period = new_period;
    call PeriodTimer.startPeriodic(period);
  }

  event void Collect.collectBooted() { }

  event void TmpP.pwrDownDone(error_t error) { }
  event void TmpX.pwrUpDone(error_t error)   { }
  event void TmpX.pwrDownDone(error_t error) { }
}
