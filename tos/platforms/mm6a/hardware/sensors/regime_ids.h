/*
 * Copyright (c) 2019, Eric B. Decker
 * All rights reserved.
 */

#ifndef REGIME_IDS_H
#define REGIME_IDS_H

/* Regime Ids (RGM_ID) are inherently platform dependent and are used to
 * control sensors on a given platform.
 *
 * RGM_IDs below RGM_MAX_ID are used by time based periodic sensors.  See
 * sns_period_table.  Higher RGM_IDs are used for various platform
 * dependent auxiliary functions.
 */

enum {
  RGM_ID_NONE		= 0,	// used for other data stream stuff
  RGM_ID_BATT		= 1,	// Battery Sensor
  RGM_ID_TEMP_PX        = 2,    // Temperature Sensor, Platform/External
  RGM_ID_SAL		= 3,	// Salinity sensor (one, two)
  RGM_ID_ACCEL		= 4,	// Accelerometer (x,y,z)
  RGM_ID_GYRO           = 5,    // Gyro
  RGM_ID_MAG            = 6,    // Magnetometer (x, y, z)
  RGM_ID_PTEMP		= 7,	// Temperature sensor

  RGM_ID_GPS            = 8,    // time based GPS kick.

  // Starting with Press, the remaining sensors are differential sensors
  RGM_DIFF_START	= 9,
  RGM_ID_PRESS		= 9,	// Pressure (temp, pressure)
  RGM_ID_SPEED		= 10,	// Velocity (x,y)

  RGM_ID_TIME_MAX       = 10,   // max. for regime array
  RGM_ID_MAX_ID		= 10,
};


enum {
  RGM_ALL_OFF           = 0,
  RGM_DEFAULT           = 1,
  RGM_MAX_REGIME        = 15,
  RGM_ONE_MIN           = (60*1024UL),
};

#endif
