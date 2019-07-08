/*
 * RegimeP.nc: implementation for regime control
 * Copyright 2008 Eric B. Decker
 * All rights reserved.
 */


/**
 *  Regime control.
 *  @author: Eric B. Decker
 */

#include "sensors.h"
#include "regime.h"

module RegimeP {
  provides interface Regime;
}
implementation {
  uint8_t  sns_regime;

  command uint8_t Regime.getCurRegime() {
    return sns_regime;
  }

  command uint32_t Regime.sensorPeriod(uint8_t sns_id) {
    if (sns_id > SNS_MAX_ID)
      return 0UL;
    return sns_period_table[sns_regime][sns_id];
  }

  command error_t Regime.setRegime(uint8_t regime) {
    if (regime > SNS_MAX_REGIME)
      return FAIL;
    sns_regime = regime;
    signal Regime.regimeChange();
    return SUCCESS;
  }


  default event void Regime.regimeChange() {};
}
