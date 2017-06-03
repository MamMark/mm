/*
 * Copyright (c) 2008, 2010, Eric B. Decker
 * All rights reserved.
 */

#ifndef BATT_H
#define BATT_H

#include "sensors.h"

/*
 * Sensor States (used to observe changes)
 */
enum {
    BATT_STATE_OFF		= 0,
    BATT_STATE_IDLE		= 1,
    BATT_STATE_READ		= 2,
};



const mm_sensor_config_t batt_config = {
  .sns_id = SNS_ID_BATT,
  .mux  = SMUX_BATT,
  .t_settle = 164,		/* ~ 5mS */
  .gmux = 0,
};

#endif
