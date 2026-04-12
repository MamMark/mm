/*
 * Copyright (c) 2019-2021, Eric B. Decker
 * All rights reserved.
 */

#ifndef REGIME_IDS_H
#define REGIME_IDS_H

/*
 * Regime Ids are used to interface between sensors and the regime system.
 * A RGM_ID is used by a sensor's implementation code to ask the Regime
 * manager for any information (typically the sensor's data rate/period)
 * needed to generate and collect information from the sensor.
 *
 * Regime Ids (RGM_ID) are inherently platform dependent and are used to
 * control sensors on a given platform.
 */

enum {
  RGM_ID_NONE           = 0,    // used for other data stream stuff
  RGM_ID_BATT           = 1,    // Battery Sensor
  RGM_ID_TMP_PX         = 2,    // Temperature Sensor, Platform/External
  RGM_ID_SAL            = 3,    // Salinity sensor (one, two)
  RGM_ID_SPEED          = 4,    // Velocity (x,y)
  RGM_ID_ACCEL          = 5,    // Accelerometer (x,y,z)
  RGM_ID_GYRO           = 6,    // Gyro
  RGM_ID_MAG            = 7,    // Magnetometer (x, y, z)
  RGM_ID_PRESS          = 8,    // Pressure (temp, pressure)

  RGM_ID_MAX            = 8,
};

enum {
  RGM_ALL_OFF           = 0,
  RGM_DEFAULT           = 1,
  RGM_MAX_REGIME        = 15,
};

#endif
