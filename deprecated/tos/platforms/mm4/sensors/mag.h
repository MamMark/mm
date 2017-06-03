/*
 * Copyright (c) 2008, 2010, Eric B. Decker
 * All rights reserved.
 */

#ifndef MAG_H
#define MAG_H

#include "sensors.h"

/*
 * Sensor States (used to observe changes)
 */
enum {
    MAG_STATE_OFF		= 0,
    MAG_STATE_IDLE		= 1,
    MAG_STATE_READ_XY_A		= 2,
    MAG_STATE_READ_XY_B		= 3,
    MAG_STATE_READ_Z		= 4,
};

/*
 * Mag is two devices with 3 parts.  The first device
 * has XY_A and XY_B.  The second device is in the
 * Z plane.  Both devices are powered up together.
 */
const mm_sensor_config_t mag_config_XY_A = {
  .sns_id = SNS_ID_MAG,
  .mux  = DMUX_MAG_XY_A,
  .t_settle = 164,          /* ~ 5mS */
  .gmux = GMUX_x400,
};

const mm_sensor_config_t mag_config_XY_B = {
  .sns_id = SNS_ID_MAG,
  .mux  = DMUX_MAG_XY_B,
  .t_settle = 4,            /* ~ 120 uS */
  .gmux = GMUX_x400,
};

const mm_sensor_config_t mag_config_Z = {
  .sns_id = SNS_ID_MAG,
  .mux  = DMUX_MAG_Z_A,
  .t_settle = 4,            /* ~ 120 uS */
  .gmux = GMUX_x400,
};

#endif
