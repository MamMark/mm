/*
 * Copyright (c) 2008, 2010, Eric B. Decker
 * All rights reserved.
 */

#ifndef CRADLE_H
#define CRADLE_H

#include "sensors.h"

/*
 * Check 4 times a minute
 */

//#define CRADLE_PERIOD (1024UL*15)
#define CRADLE_PERIOD (1024UL)

#define CRADLE_THRESHOLD (40000UL)

/*
 * There is the first value, then counts is needed for a total
 * of counts+1.  If we are sampling at 1024 mis then 5 secs.
 */
#define CRADLE_DEBOUNCE_COUNTS 4

/*
 * Sensor States (used to observe changes)
 */
enum {
    CRADLE_STATE_OFF		= 0,
    CRADLE_STATE_IDLE		= 1,
    CRADLE_STATE_READ		= 2,
};



const mm_sensor_config_t cradle_config = {
  .sns_id = SNS_ID_CRADLE,
  .mux  = SMUX_BATT,
  .t_settle = 164,		/* ~ 5mS */
  .gmux = 0,
};

#endif
