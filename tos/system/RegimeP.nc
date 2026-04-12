/*
 * RegimeP.nc: implementation for regime control
 * Copyright 2008, 2020-2021 Eric B. Decker
 * All rights reserved.
 */


/**
 *  Regime control.
 *  @author: Eric B. Decker
 */

#include "regime_ids.h"
#include "platform_regime.h"
#include <sensor_config.h>

module RegimeP {
  provides interface Regime;
}
implementation {
  uint8_t  cur_regime;

  command uint8_t Regime.getCurRegime() {
    return cur_regime;
  }

  command uint32_t Regime.sensorPeriodMs(uint8_t rgm_id) {
    if (rgm_id > RGM_ID_MAX)
      return 0UL;
    return sns_period_table[cur_regime][rgm_id]/SNS_US2MS_B;
  }

  command uint32_t Regime.sensorPeriodUs(uint8_t rgm_id) {
    if (rgm_id > RGM_ID_MAX)
      return 0UL;
    return sns_period_table[cur_regime][rgm_id];
  }

  command error_t Regime.setRegime(uint8_t regime) {
    if (regime > RGM_MAX_REGIME)
      return FAIL;
    cur_regime = regime;
    signal Regime.regimeChange();
    return SUCCESS;
  }


  default event void Regime.regimeChange() {};
}
