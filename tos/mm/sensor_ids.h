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

enum {                                  /* uint16_t sns_id */
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

  /* Accel, 3 x uint16, nsamples */
  SNS_ID_ACCEL_N        = 4,    // Accelerometer (x,y,z)
  SNS_ID_ACCEL_N8       = 5,    // 8 bit data
  SNS_ID_ACCEL_N10      = 6,    // 10 bit data, 2 bytes
  SNS_ID_ACCEL_N12      = 7,    // 12 bit data, 2 bytes

  /* Gyro, 3 x uint16, nsamples */
  SNS_ID_GYRO_N         = 16,   // Gyro, 16 bit data

  /* Magnetometer, 3 x uint16, nsamples */
  SNS_ID_MAG_N          = 17,   // Magnetometer (x, y, z), 16 bit data

  SNS_ID_GPS            = 18,   // time based GPS kick.  ???

  /* Pressure transducer
   * Ptemp: uint16
   * Press: uint16
   */
  SNS_ID_PTEMP          = 32,   // Temperature sensor
  SNS_ID_PRESS          = 33,   // Pressure (temp, pressure)

  /* Velocity, 2 x uint16 */
  SNS_ID_SPEED          = 34,   // Velocity (x,y)
};

#endif
