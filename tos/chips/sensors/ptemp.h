/*
 * Copyright (c) 2008, Eric B. Decker
 * All rights reserved.
 */

#ifndef PTEMP_H
#define PTEMP_H

#include "sensors.h"

/*
 * Sensor States (used to observe changes)
 */
enum {
    PTEMP_STATE_OFF		= 0,
    PTEMP_STATE_IDLE		= 1,
    PTEMP_STATE_READ		= 2,
};


const mm3_sensor_config_t ptemp_config = {
  .sns_id = SNS_ID_PTEMP,
  .mux  = SMUX_PRESS_TEMP,
  .t_settle = 164,		/* ~ 5mS */
  .gmux = 0,
};

#endif
