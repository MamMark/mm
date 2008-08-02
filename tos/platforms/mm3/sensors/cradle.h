/*
 * Copyright (c) 2008, Eric B. Decker
 * All rights reserved.
 */

#ifndef CRADLE_H
#define CRADLE_H

#include "sensors.h"

/*
 * Once a minute
 */

//#define CRADLE_PERIOD (1024UL*60*1)
#define CRADLE_PERIOD (1024UL)

/*
 * Sensor States (used to observe changes)
 */
enum {
    CRADLE_STATE_OFF		= 0,
    CRADLE_STATE_IDLE		= 1,
    CRADLE_STATE_READ		= 2,
};



const mm3_sensor_config_t cradle_config = {
  .sns_id = SNS_ID_CRADLE,
  .mux  = SMUX_BATT,
  .t_settle = 164,		/* ~ 5mS */
  .gmux = 0,
};

#endif
