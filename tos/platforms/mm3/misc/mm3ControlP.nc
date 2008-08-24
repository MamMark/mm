/*
 * Copyright (c) 2008, Eric B. Decker
 * All rights reserved.
 */

#include "sensors.h"
#include "sal.h"

#define EAVES TRUE

module mm3ControlP {
  provides {
    interface mm3Control[uint8_t sns_id];
    interface Init;
    interface Surface;
  }
  uses {
    interface Panic;
    interface SenseVal[uint8_t sns_id];
  }
}

implementation {
  bool eaves[MM3_NUM_SENSORS];
  bool m_surfaced;

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
    if (sns_id == SNS_ID_SAL) {
      if (m_surfaced) {
	if (data < SURFACE_THRESHOLD) {
	  m_surfaced = FALSE;
//	  signal Surface.submerged();
	}
      } else {
	if (data >= SURFACE_THRESHOLD) {
	  m_surfaced = TRUE;
//	  signal Surface.surfaced();
	}
      }
    }
  }

#ifdef notdef
  /*
   * default commands aren't needed.  Right?  ask kevin   How are default commands
   * used?
   */
  default command bool mm3Control.eavesdrop[uint8_t sns_id]() { return SUCCESS; }
#endif
}
