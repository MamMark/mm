/*
 * Copyright (c) 2008, 2010, Eric B. Decker
 * All rights reserved.
 */

#ifndef SPEED_H
#define SPEED_H

#include "sensors.h"

/*
 * Sensor States (used to observe changes)
 */
enum {
    SPEED_STATE_OFF		= 0,
    SPEED_STATE_IDLE		= 1,
    SPEED_STATE_READ_1		= 2,
    SPEED_STATE_READ_2		= 3,
};


const mm_sensor_config_t speed_config_1 = {
  .sns_id = SNS_ID_SPEED,
  .mux  = DMUX_SPEED_1,
  .t_settle = 164,		/* ~ 5mS */
  .gmux = GMUX_x400,
};


const mm_sensor_config_t speed_config_2 = {
  .sns_id = SNS_ID_SPEED,
  .mux  = DMUX_SPEED_2,
  .t_settle = 4,		/* ~ 120 uS */
  .gmux = GMUX_x400,
};

#endif
