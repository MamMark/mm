/*
 * Copyright (c) 2008, Eric B. Decker
 * All rights reserved.
 */

#ifndef ACCEL_H
#define ACCEL_H

#include "sensors.h"

/*
 * Sensor States (used to observe changes)
 */
enum {
    ACCEL_STATE_OFF		= 0,
    ACCEL_STATE_IDLE		= 1,
    ACCEL_STATE_READ_X		= 2,
    ACCEL_STATE_READ_Y		= 3,
    ACCEL_STATE_READ_Z		= 4,
};

/*
 * Accel is one device with 3 parts.  First X is used
 * and its settling time is used to power the device up
 * Once X is done the other two are sequenced to get
 * Y and Z.  Settling times are set to be a simple
 * smux change.
 */
const mm3_sensor_config_t accel_config_X =
{ .sns_id = SNS_ID_ACCEL,
  .mux  = SMUX_ACCEL_X,
  .t_settle = 164,          /* ~ 5mS */
  .gmux = 0,
};

const mm3_sensor_config_t accel_config_Y =
{ .sns_id = SNS_ID_ACCEL,
  .mux  = SMUX_ACCEL_Y,
  .t_settle = 4,            /* ~ 120 uS */
  .gmux = 0,
};

const mm3_sensor_config_t accel_config_Z =
{ .sns_id = SNS_ID_ACCEL,
  .mux  = SMUX_ACCEL_Z,
  .t_settle = 4,            /* ~ 120 uS */
  .gmux = 0,
};

#endif
