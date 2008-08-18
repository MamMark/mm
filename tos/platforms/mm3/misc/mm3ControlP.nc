/*
 * Copyright (c) 2008, Eric B. Decker
 * All rights reserved.
 */

#include "sensors.h"

#define EAVES TRUE

module mm3ControlP {
  provides {
    interface mm3Control[uint8_t sns_id];
    interface Init;
  }
  uses {
    interface Panic;
    interface SenseVal[uint8_t sns_id];
  }
}

implementation {
  bool eaves[MM3_NUM_SENSORS];

  command bool mm3Control.eavesdrop[uint8_t sns_id]() {
    if (sns_id < MM3_NUM_SENSORS)
      return eaves[sns_id];
    return FALSE;
  }

  command error_t Init.init() {
    uint8_t i;

    for (i = 0; i < MM3_NUM_SENSORS; i++)
      eaves[i] = EAVES;
    return SUCCESS;
  }

  event void SenseVal.valAvail[uint8_t sns_id](uint16_t data, uint32_t stamp) {
    nop();
  }

#ifdef notdef
  /*
   * default commands aren't needed.  Right?  ask kevin   How are default commands
   * used?
   */
  default command bool mm3Control.eavesdrop[uint8_t sns_id]() { return SUCCESS; }
#endif
}
