/* 
 * snsRegime.nc: interface definition for regime control
 * Copyright 2008 Eric B. Decker
 * All rights reserved.
 */


/**
 *  Interface to regime control.
 *  @author: Eric B. Decker
 */

interface Regime {

  command uint8_t getCurRegime();

  command uint32_t sensorPeriod(uint8_t sns_id);

  command error_t setRegime(uint8_t regime);

  event void regimeChange();
}
