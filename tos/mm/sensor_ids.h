/*
 * Copyright (c) 2019, Eric B. Decker
 * All rights reserved.
 */

#ifndef SENSORS_IDS_H
#define SENSORS_IDS_H

/* MM Sensors
 *
 * Sensors report data obtained from sensor hardware drivers.
 * Single datums may be reported (simple sensor) or as aggregates
 * of multiple datums (composite sensor).
 *
 * A given sensor id (SNS_ID) denotes a specific format of any
 * data following the dt_sensor_data record header.  This format
 * reflects both the number of datums as well as the explicit format
 * of each datum.
 *
 * SNS_IDs are globally unique and apply across different sensor platforms.
 * The sensor driver is responsible for collecting any data needed and
 * setting the appropriate SNS_ID in the dt_sensor_data header to reflect
 * the format of the data stored.
 *
 * Definitions should also be reflected in tagcore definitions:
 * sensor_defs.py, sensor_headers.py, etc.
 */

enum {
  SNS_ID_NONE           = 0,

  /* Simple Battery Sensor, 1 x uint16 */
  SNS_ID_BATT           = 1,    // Battery Sensor

  /* Composite temperature, Platform and External temperature sensors.
   * 2 x uint16, tmp102 format
   *
   * Tmp102 based, 2 uint16 values in native tmp102 format,
   * 1st value is on board platform sensor, 2nd external.
   *
   * 12 bit twos-complement (upper 12 bits of the 16 bit value).  Each
   * unit value represents 0.0625 degrees C.
   */
  SNS_ID_TEMP_PX        = 2,    // Temperature Sensor, Platform/External

  /* Salinity, 2 x uint16 */
  SNS_ID_SAL            = 3,    // Salinity sensor (one, two)

  /* Accel, 3 x uint16 */
  SNS_ID_ACCEL          = 4,    // Accelerometer (x,y,z)

  /* Gyro, 3 x uint16 */
  SNS_ID_GYRO           = 5,    // Gyro

  /* Magnetometer, 3 x uint16 */
  SNS_ID_MAG            = 6,    // Magnetometer (x, y, z)

  SNS_ID_GPS            = 7,    // time based GPS kick.

  /* Pressure transducer
   * Ptemp: uint16
   * Press: uint16
   */
  SNS_ID_PTEMP          = 8,    // Temperature sensor
  SNS_ID_PRESS          = 9,    // Pressure (temp, pressure)

  /* Velocity, 2 x uint16 */
  SNS_ID_SPEED          = 10,   // Velocity (x,y)

  SNS_ID_GPS_GEO        = 11,   // lat/long
  SNS_ID_GPS_XYZ        = 12,   // ecef
  SNS_ID_GPS_TIME       = 13,   // gps time
};

#endif
