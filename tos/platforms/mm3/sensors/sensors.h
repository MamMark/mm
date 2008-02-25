/*
 * Copyright (c) 2008, Eric B. Decker
 * All rights reserved.
 */

#ifndef SENSORS_H
#define SENSORS_H


enum {
    DMUX_MAG_XY_B	= 0,
    DMUX_MAG_Z_A	= 1,
    DMUX_MAG_XY_A	= 2,
    DMUX_SPEED_1	= 4,
    DMUX_SPEED_2	= 5,
    DMUX_PRESS		= 6
};


enum {
    SMUX_ACCEL_Y	= 0,
    SMUX_ACCEL_X	= 1,
    SMUX_SALINITY	= 2,
    SMUX_PRESS_TEMP	= 3,
    SMUX_TEMP		= 4,
    SMUX_DIFF		= 5,
    SMUX_ACCEL_Z	= 6,
    SMUX_BATT		= 7
};


enum {
    GMUX_x2		= 0,
    GMUX_x20		= 1,
    GMUX_x200		= 2,
    GMUX_x400		= 3
};


/*
 * Sensor States (used to observe changes)
 */
enum {
    SNS_STATE_OFF		= 0,
    SNS_STATE_PERIOD_WAIT	= 1,
    SNS_STATE_ADC_WAIT		= 2,
    SNS_STATE_PART_2_WAIT	= 3,
    SNS_STATE_PART_3_WAIT	= 4,
};

typedef uint8_t  sensor_id_t;
typedef uint16_t sensor_data_t;


#define SNS_MAX_REGIME		5

/*
 * mm3_sensor_config_t is used to pass information from the
 * adc client to the adc subsystem about how to configure
 * the adc h/w for the sensor read being requested.
 */

typedef struct {
  uint8_t	sns_id;
  uint8_t	mux;
  uint8_t	gmux;
  uint8_t	fill;
  uint16_t	t_powerup;
} mm3_sensor_config_t;


/*
 * Various power up times.  All times in uSecs.
 * for the time being use millisecs
 */
#ifdef notdef
#define VREF_POWERUP_DELAY	1000
#define VDIFF_POWERUP_DELAY	2000
#define VDIFF_SWING_DELAY	1000
#endif

#define VREF_POWERUP_DELAY	1
#define VDIFF_POWERUP_DELAY	2
#define VDIFF_SWING_DELAY	1
#define VDIFF_SWING_GAIN	GMUX_x2
#define VDIFF_SWING_DMUX	DMUX_PRESS


/* MM3 Sensors

   A primitive sensor is either a single sensor or a sequence
   of single sensors that need to be read at one time.  For
   example the accelerometer consists of a single chip (powered
   once) and requires 3 data cycles (X, Y, and Z).  These
   3 values need to be read back to back.

   Each primitive sensor is represented in the ADC subsystem
   by a sensor id and a single bit in the ADC arbiter (sns_id - 1).
   The ADC can be handling one primitive sensor at a time and must
   be protected by an arbiter.

   Values obtained from the sensors are passed via the buffer
   that is part of the getData interface similar to the MultiChannel
   interface provided in the MSP430 ADC12 implementation.  This
   interface is used for both single and multiple values.

   Singleton sensors include Battery and Temp.

   Sequenced sensors include Salinity (2 x 16), Accel (3 x 16),
   Pressure (2 x 16, pressure and pressure temp), Speed (2 x 16),
   and Magnatometer (3 x 16).
*/

enum {
  SNS_ID_NONE		= 0,
  SNS_ID_BATT		= 1,
  SNS_ID_TEMP		= 2,
  SNS_ID_SAL		= 3,

  /* accel_x, _y, and _z */
  SNS_ID_ACCEL		= 4,
  SNS_ID_PTEMP		= 5,

  /* Starting with Press, the remaining
     sensors are differential sensors
  */

#define SNS_DIFF_START		6

  /* press temp and pressure */
  SNS_ID_PRESS		= 6,

  /* speed_1 and speed_2 */
  SNS_ID_SPEED		= 7,

  /* mag_xy_a, xy_b, z_a */
  SNS_ID_MAG		= 8,
#define SNS_PART_MAG_Z		1

#define SNS_ID_FIRST		1
#define SNS_ID_LAST		8

#define SNS_REG_ID_LIMIT	9

  // last entry
  SENSOR_SENTINEL	= 9
};


#ifdef notdef
const mm3_sensor_config_t sensor_configs[] = {
  /* NONE */
  { .sns_id = SNS_ID_NONE,
    .mux_1 = 0, .mux_2 = 0, .mux_3 = 0,
    .gmux = 0,  .t_powerup = 0 },

  /* BATTERY */
  { .sns_id = SNS_ID_BATT,
    .mux_1 = SMUX_BATT, .mux_2 = 0, .mux_3 = 0,
    .gmux = 0,  .t_powerup = 1 },

  /* TEMP */
  { .sns_id = SNS_ID_TEMP,
    .mux_1 = SMUX_TEMP, .mux_2 = 0, .mux_3 = 0,
    .gmux = 0,  .t_powerup = 5 },

  /* SALINITY */
  { .sns_id = SNS_ID_SALINITY,
    .mux_1 = SMUX_SALINITY, .mux_2 = 0, .mux_3 = 0,
    .gmux = 0,  .t_powerup = 1 },

  /* ACCEL */
  { .sns_id = SNS_ID_ACCEL,
    .mux_1 = SMUX_ACCEL_X, .mux_2 = SMUX_ACCEL_Y, .mux_3 = SMUX_ACCEL_Z,
    .gmux = 0,  .t_powerup = 1 },

  /* PTEMP */
  { .sns_id = SNS_ID_PTEMP,
    .mux_1 = SMUX_PRESS_TEMP, .mux_2 = 0, .mux_3 = 0,
    .gmux = 0,  .t_powerup = 5 },

  /* PRESSURE */
  { .sns_id = SNS_ID_PRESS,
    .mux_1 = DMUX_PRESS, .mux_2 = 0, .mux_3 = 0,
    .gmux = GMUX_x400,  .t_powerup = 1 },

  /* SPEED */
  { .sns_id = SNS_ID_SPEED,
    .mux_1 = DMUX_SPEED_1, .mux_2 = DMUX_SPEED_2, .mux_3 = 0,
    .gmux = GMUX_x400,  .t_powerup = 1 },

  /* MAG */
  { .sns_id = SNS_ID_MAG,
    .mux_1 = DMUX_MAG_XY_A, .mux_2 = DMUX_MAG_XY_B, .mux_3 = DMUX_MAG_Z_A,
    .gmux = GMUX_x400,  .t_powerup = 1 },

  /* SENSOR_SENTINEL */
  { .sns_id = SNS_ID_NONE,
    .mux_1 = 0, .mux_2 = 0, .mux_3 = 0,
    .gmux = 0,  .t_powerup = 0 },
};
#endif


/* Test for GCC bug (bitfield access) - only version 3.2.3 is known to be stable */
// TODO: check whether this is still relevant...
#define GCC_VERSION (__GNUC__ * 100 + __GNUC_MINOR__ * 10 + __GNUC_PATCHLEVEL__)
#if GCC_VERSION == 332
#error "The msp430-gcc version (3.3.2) contains a bug which results in false accessing \
of bitfields in structs and makes MSP430ADC12M.nc fail ! Use version 3.2.3 instead."
#elif GCC_VERSION != 323
#warning "This version of msp430-gcc might contain a bug which results in false accessing \
of bitfields in structs. Use version 3.2.3 instead."
#endif  

#endif
