/*
 * Copyright (c) 2019, Eric B. Decker
 * All rights reserved.
 */

#ifndef SENSORS_H
#define SENSORS_H

typedef uint8_t  sensor_id_t;
typedef uint16_t sensor_data_t;

/* MM Sensors

   A primitive sensor is either a single sensor or a sequence
   of single sensors that need to be read at one time.  For
   example the accelerometer consists of a single chip that
   requires a read, once for each axis (X, Y, and Z).

   Values obtained from the sensors are passed via the buffer
   that is part of the getData interface similar to the MultiChannel
   interface provided in the MSP430 ADC12 implementation.  This
   interface is used for both single and multiple values.
*/

enum {
  SNS_ID_NONE		= 0,	// used for other data stream stuff
  SNS_ID_BATT		= 1,	// Battery Sensor
  SNS_ID_TEMP_PX        = 2,    // Temperature Sensor, Platform/External
  SNS_ID_SAL		= 3,	// Salinity sensor (one, two)
  SNS_ID_ACCEL		= 4,	// Accelerometer (x,y,z)
  SNS_ID_GYRO           = 5,    // Gyro
  SND_ID_MAG            = 6,    // Magnetometer (x, y, z)
  SNS_ID_PTEMP		= 7,	// Temperature sensor

  SNS_ID_GPS            = 8,    // time based GPS kick.

  // Starting with Press, the remaining sensors are differential sensors
  SNS_DIFF_START	= 9,
  SNS_ID_PRESS		= 9,	// Pressure (temp, pressure)
  SNS_ID_SPEED		= 10,	// Velocity (x,y)

  MM_MAX_TIME           = 11,   // max. time based. one larger

  // misc. none time based sensors.
  SNS_GPS_GEO           = 11,   // lat/long
  SNS_GPS_XYZ           = 12,   // ecef
  SNS_GPS_TIME          = 13,   // gps time

  SNS_MAX_ID		= 13,
  MM_NUM_SENSORS	= 14,	// includes none
};

/*
 * should be same as MM_NUM_SENSORS
 */
#define NUM_SENSORS 14

#endif
