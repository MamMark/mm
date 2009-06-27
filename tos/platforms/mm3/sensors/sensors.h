/*
 * Copyright (c) 2008, Eric B. Decker
 * All rights reserved.
 */

#ifndef SENSORS_H
#define SENSORS_H

typedef uint8_t  sensor_id_t;
typedef uint16_t sensor_data_t;

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
   Pressure (2 x 16, pressure and pressure temp), Velocity (2 x 16),
   and Magnatometer (3 x 16).


   NOTE: SNS_ID 0 (SNS_ID_NONE) is used when added information to the data
   stream.  The information is still in data_block format (see sd_blocks.h)
   but doesn't have a normal sensor id associated with it.
*/

enum {
  SNS_ID_NONE		= 0,	// used for other data stream stuff
  SNS_ID_CRADLE		= 1,	// detect cradle (batt but batt off)
  SNS_ID_BATT		= 2,	// Battery Sensor
  SNS_ID_TEMP		= 3,	// Temperature Sensor
  SNS_ID_SAL		= 4,	// Salinity sensor (one, two)
  SNS_ID_ACCEL		= 5,	// Accelerometer (x,y,z)
  SNS_ID_PTEMP		= 6,	// Temperature sensor

  /* Starting with Press, the remaining
     sensors are differential sensors
  */
  SNS_DIFF_START	= 7,
  SNS_ID_PRESS		= 7,	// Pressure (temp, pressure)
  SNS_ID_SPEED		= 8,	// Velocity (x,y)
  SNS_ID_MAG		= 9,    // Magnetometer (x,y,z)

  SNS_MAX_ID		= 9,

  /*
   * MM3_NUM_SENSORS controls how many sensors are compiled into the system.  This also
   * effects allocation of communication message structures.  The allocation doesn't happen
   * automagically as it should so one needs to search all files for use of MM3_NUM_SENSORS and
   * make the changes manually.  For example, mm3CommDataP.nc needs to have pointers to each
   * of the sensor data packets.  But this is done manually since we want it to be allocated
   * in code space.
   */
  MM3_NUM_SENSORS	= 10,	// includes none
};

/*
 * should be same as MM3_NUM_SENSORS
 */
#define NUM_SENSORS 10


/*
 * Mux setings to read from sensors
 */
enum {
  DMUX_MAG_XY_B		= 0,
  DMUX_MAG_Z_A		= 1,
  DMUX_MAG_XY_A		= 2,
  DMUX_SPEED_1		= 4,
  DMUX_SPEED_2		= 5,
  DMUX_PRESS		= 6
};

enum {
  SMUX_ACCEL_Y		= 0,
  SMUX_ACCEL_X		= 1,
  SMUX_SALINITY		= 2,
  SMUX_PRESS_TEMP	= 3,
  SMUX_TEMP			= 4,
  SMUX_DIFF			= 5,
  SMUX_ACCEL_Z		= 6,
  SMUX_BATT			= 7
};

enum {
  GMUX_x2			= 0,
  GMUX_x20			= 1,
  GMUX_x200			= 2,
  GMUX_x400			= 3
};

/*
 * Various power up times.  All times in 32KHz jiffies.
 */

#define VREF_POWERUP_DELAY	33
#define VDIFF_POWERUP_DELAY	66
#define VDIFF_SWING_DELAY	33
#define VDIFF_SWING_GAIN	GMUX_x2
#define VDIFF_SWING_DMUX	DMUX_PRESS

/*
 * mm3_sensor_config_t is used to pass information from the
 * adc client to the adc subsystem about how to configure
 * the adc h/w for the sensor read being requested.
 *
 * sensor type is determined by its id.  >= SNS_DIFF_START
 * the sensor is differential.
 *
 * mux:		smux value or dmux value dependent on sensor type
 * t_settle:	settling time for sensor.  If 1st time powered up
 *		is power up time.  Can also be smux switching time.
 *
 *		settling times are in 32KHz jiffies.  1 jiffy = ~30.5 uS.
 * gmux:	gmux value for differential sensor.
 */

typedef struct {
  uint8_t	sns_id;			// Sensor ID
  uint8_t	mux;			// Smux or Dmux value
  uint16_t	t_settle;		// Setting time for configuration to complete
  uint8_t	gmux;			// gmux value if differential sensor (i.e. sns_id >= 6)
} mm3_sensor_config_t;

#include "sd_blocks.h"

#endif
