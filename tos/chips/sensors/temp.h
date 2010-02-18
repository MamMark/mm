/*
 * Copyright (c) 2008, 2010, Eric B. Decker
 * All rights reserved.
 */

#ifndef TEMP_H
#define TEMP_H

#include "sensors.h"

/*
 * Sensor States (used to observe changes)
 */
enum {
    TEMP_STATE_OFF		= 0,
    TEMP_STATE_IDLE		= 1,
    TEMP_STATE_READ		= 2,
};

const mm_sensor_config_t temp_config = {
  .sns_id = SNS_ID_TEMP,
  .mux  = SMUX_TEMP,
  .t_settle = 164,          /* ~ 5mS */
  .gmux = 0,
};

#endif
