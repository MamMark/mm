/*
 * Copyright (c) 2008, 2010, Eric B. Decker
 * All rights reserved.
 */

#ifndef PRESS_H
#define PRESS_H

#include "sensors.h"

/*
 * Sensor States (used to observe changes)
 */
enum {
    PRESS_STATE_OFF		= 0,
    PRESS_STATE_IDLE		= 1,
    PRESS_STATE_READ		= 2,
};

/*
 * Press is one device with 2 parts.  One part is
 * the pressure temperature which is a simple resistor
 * network.  This is single ended.  The other part is
 * the pressure sensor itself which is differential.
 * To simplify, the pressure temp is split off.  Any
 * power implications are handled when powering up
 * and down.
 */

const mm_sensor_config_t press_config = {
  .sns_id = SNS_ID_PRESS,
  .mux  = DMUX_PRESS,
  .t_settle = 164,		/* ~ 5mS */
  .gmux = GMUX_x400,
};

#endif
