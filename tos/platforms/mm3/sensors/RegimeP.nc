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

module RegimeP {
  provides interface Regime;
  provides interface Init;
}
implementation {
  uint8_t  sns_regime;

  /*
   * All times in milliseconds.
   */

  const uint32_t sns_period_table[SNS_MAX_REGIME][SNS_REG_ID_LIMIT] = {
    /*    none	    bat		temp	    sal	    accel   ptemp */
    {     0UL,	    0UL,	0UL,	    0UL,    0UL,    0UL,	/* 0 - all off  */

    /*    press	    speed	mag  */
	  0UL,	    0UL,	0UL    },

    {     0UL,	    10000UL,	1000UL,	    1000UL, 50UL,   1000UL,	/* 1 - main regime */
	  1000UL,   1000UL,	50UL   },

    {     0UL,      1000UL,	1000UL,	    1000UL, 1000UL, 1000UL,	/* 2 - all sensors once/sec */
	  1000UL,   1000UL,	1000UL },


    {     0UL,	    1000UL,	0UL,	    0UL,    0UL,    0UL,	/* 3 - batt only */
	  0UL,	    0UL,	0UL    },

    {     0UL,      1000UL,	1001UL,	    1002UL, 1003UL, 1004UL,	/* 4 - testing */
	  1005UL,   1006UL,	1007UL },
  };


  command error_t Init.init() {
    sns_regime = 4;
    return SUCCESS;
  }


  command uint8_t Regime.getCurRegime() {
    return sns_regime;
  }


  command uint32_t Regime.sensorPeriod(uint8_t sns_id) {
    if (sns_regime >= SNS_MAX_REGIME)
      return 0UL;
    if (sns_id >= SENSOR_SENTINEL)
      return 0UL;
    return sns_period_table[sns_regime][sns_id];
  }

  command error_t Regime.setRegime(uint8_t regime) {
    if (sns_regime >= SNS_MAX_REGIME)
      return FAIL;
    sns_regime = regime;
    signal Regime.regimeChange();
    return SUCCESS;
  }

  default event void Regime.regimeChange() {};
}
