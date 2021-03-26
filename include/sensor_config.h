/*
 * Copyright (c) 2021, Eric B. Decker
 * All rights reserved.
 */

#ifndef SENSOR_CONFIG_H
#define SENSOR_CONFIG_H

/* globally unique id code for what sensor is being described */
typedef enum {
  SNS_ID_NONE           = 0,
  SNS_ID_LSM6_ACCEL     = 1,
  SNS_ID_LSM6_GYRO      = 2,
  SNS_ID_LIS2MDL_MAG    = 3,
  SNS_ID_QUAD           = 0xffffffff,   /* force to quad */
} sensor_id_t;


typedef struct {
  uint32_t period;
  uint32_t fs;
  uint32_t filter;
  sensor_id_t sensor_id;
} sensor_config_t;


/*
 * Periods are denoted in decimal microsecs.
 *
 * full scale (fs) and filter are sensor dependent.
 *
 * Various complex sensors, multiple sensing elements, fifo data delivery
 * provide for various fixed output data rates.  A configuration block
 * presents to a sensors initializer what it needs for configuration.
 */

enum {
  /* DMS - decimal vs. BMS - binary milliseconds */
  DMS_SEC               = (1000UL),
  BMS_SEC               = (1024UL),
  DMS_MIN               = (60*1000UL),
  BMS_MIN               = (60*1024UL),

  SNS_US2MS             = 1000,
  SNS_US2MS_B           = 1024,


  /*
   * values used by complex sensors, fifo driven, ODR/periods
   * used in regime and configuration structures.
   *
   * In decimal micro seconds.
   */

  SNS_1HZ               = 1000000UL,
  SNS_1D6HZ             =  625000UL,
  SNS_10HZ              =  100000UL,
  SNS_12D5HZ            =   80000UL,
  SNS_20HZ              =   50000UL,
  SNS_25HZ              =   40000UL,
  SNS_26HZ              =   38462UL,
  SNS_50HZ              =   20000UL,
  SNS_52HZ              =   19231UL,
  SNS_75HZ              =   13333UL,
  SNS_100HZ             =   10000UL,
  SNS_104HZ             =    9615UL,
  SNS_208HZ             =    4808UL,
  SNS_416HZ             =    2404UL,
  SNS_833HZ             =    1200L,
  SNS_1666HZ            =     600L,
  SNS_3333HZ            =     300L,
  SNS_6666HZ            =     150L,

};

#endif
