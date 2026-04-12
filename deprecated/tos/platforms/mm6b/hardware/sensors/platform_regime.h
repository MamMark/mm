/*
 * Copyright (c) 2019, Eric B. Decker
 * All rights reserved.
 */

#include "regime_ids.h"

#ifndef PLATFORM_REGIME_H
#define PLATFORM_REGIME_H

/*
 * All times in binary milliseconds (mis).
 */
const uint32_t sns_period_table[RGM_MAX_REGIME + 1][RGM_ID_TIME_MAX + 1] = {

  /* none  batt         tmpPX   sal     accel   gyro    mag     ptemp   gps     press   speed  */
  {  0UL,  0UL,         0UL,    0UL,    0UL,    0UL,    0UL,    0UL,    0UL,    0UL,    0UL    }, /* 0 - all off  */
  {  0UL,  RGM_ONE_MIN, RGM_ONE_MIN,
                                1024UL, 102UL,  0UL,    0UL,    1024UL, 0UL,    1024UL, 1024UL }, /* 1 - main regime */
  {  0UL,  1024UL, RGM_ONE_MIN,
                                1024UL, 1024UL, 0UL,    0UL,    1024UL, 0UL,    1024UL, 1024UL }, /* 2 - all sensors once/sec */
  {  0UL,  RGM_ONE_MIN, 0UL,    0UL,    102UL,  0UL,    0UL,    0UL,    0UL,    0UL,    0UL    }, /* 3 - batt and accel only, 10Hz */
  {  0UL,  RGM_ONE_MIN, 0UL,    0UL,    0UL,    0UL,    0UL,    0UL,    0UL,    0UL,    0UL    }, /* 4 * */
  {  0UL,  0UL,         RGM_ONE_MIN,
                                0UL,    0UL,    0UL,    0UL,    0UL,    0UL,    0UL,    0UL    }, /* 5 */
  {  0UL,  0UL,         0UL,    512UL,  0UL,    0UL,    0UL,    0UL,    0UL,    0UL,    0UL    }, /* 6 */
  {  0UL,  0UL,         0UL,    0UL,    51UL,   0UL,    0UL,    0UL,    0UL,    0UL,    0UL    }, /* 7 - accel, 20 Hz */
  {  0UL,  0UL,         0UL,    0UL,    0UL,    0UL,    0UL,    512UL,  0UL,    0UL,    0UL    }, /* 8 */
  {  0UL,  0UL,         0UL,    0UL,    0UL,    0UL,    0UL,    0UL,    0UL,    512UL,  0UL,   }, /* 9 */
  {  0UL,  0UL,         0UL,    0UL,    0UL,    0UL,    0UL,    0UL,    0UL,    0UL,    512UL  }, /* 10 */
  {  0UL,  0UL,         0UL,    0UL,    0UL,    0UL,    0UL,    0UL,    0UL,    0UL,    0UL    }, /* 11 - mag, 20Hz */
  {  0UL,  51UL,        51UL,   51UL,   51UL,   0UL,    0UL,    51UL,   0UL,    51UL,   51UL   }, /* 12 - all sensors 20 Hz */
  {  0UL,  102UL,       102UL,  102UL,  102UL,  0UL,    0UL,    102UL,  0UL,    102UL,  102UL  }, /* 13 - all sensors 10 Hz */
  {  0UL,  RGM_ONE_MIN, RGM_ONE_MIN,
                                1024UL, 102UL,  0UL,    0UL,    0UL,    0UL,    0UL,    0UL    }, /* 14 - testing */
  {  0UL,  0UL,         0UL,    0UL,    51UL,   0UL,    0UL,    0UL,    0UL,    0UL,    0UL    }, /* 15 - accel, mag, 20 Hz */
};

#endif
