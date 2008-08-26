/*
 * Copyright (c) 2008, Eric B. Decker
 * All rights reserved.
 */

#include "sensors.h"
#include "sal.h"

#define EAVES TRUE

#ifdef FAKE_SURFACE
#define SURFACE_TIME   (60*1024UL)
#define SUBMERGED_TIME (10*1024UL)
#endif

module mm3ControlP {
  provides {
    interface mm3Control[uint8_t sns_id];
    interface Init;
    interface Surface;
  }
  uses {
    interface Panic;
    interface SenseVal[uint8_t sns_id];
#ifdef FAKE_SURFACE
    interface Timer<TMilli> as SurfaceTimer;
#endif
  }
}

implementation {
  bool eaves[MM3_NUM_SENSORS];
  bool m_surfaced;

#ifdef FAKE_SURFACE
  bool fake_surfaced;
#endif

  command bool mm3Control.eavesdrop[uint8_t sns_id]() {
    if (sns_id < MM3_NUM_SENSORS)
      return eaves[sns_id];
    return FALSE;
  }

  command error_t Init.init() {
    uint8_t i;

    for (i = 0; i < MM3_NUM_SENSORS; i++)
      eaves[i] = EAVES;
#ifdef FAKE_SURFACE
    call SurfaceTimer.startOneShot(SUBMERGED_TIME);
#endif
    return SUCCESS;
  }

#ifdef FAKE_SURFACE
  event void SurfaceTimer.fired() {
    if (fake_surfaced > 1)
      fake_surfaced = 1;
    fake_surfaced ^= 1;
    if (fake_surfaced)
      call SurfaceTimer.startOneShot(SURFACE_TIME);
    else
      call SurfaceTimer.startOneShot(SUBMERGED_TIME);
  }
#endif

  event void SenseVal.valAvail[uint8_t sns_id](uint16_t data, uint32_t stamp) {
#ifdef FAKE_SURFACE
    if (fake_surfaced)
      data = 65010UL;
    else
      data = 400UL;
#endif
    switch (sns_id) {
      default:
	return;

      case SNS_ID_SAL:
	if (m_surfaced) {
	  if (data < SURFACE_THRESHOLD) {
	    m_surfaced = FALSE;
	    call Panic.brk();
	    signal Surface.submerged();
	  }
	} else {
	  if (data >= SURFACE_THRESHOLD) {
	    m_surfaced = TRUE;
	    call Panic.brk();
	    signal Surface.surfaced();
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
