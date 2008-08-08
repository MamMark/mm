/*
 * Copyright (c) 2008, Eric B. Decker
 * All rights reserved.
 */

#ifndef REGIME_H
#define REGIME_H

#include "sensors.h"

#define SNS_ALL_OFF_REGIME		0
#define SNS_DEFAULT_REGIME		1
#define SNS_MAX_REGIME			15
#define MM3_NUM_REGIMES			(SNS_MAX_REGIME + 1)
  
/*
 * All times in milliseconds.  Or should they be in binary milliseconds?  (mis?)
 */
const uint32_t sns_period_table[MM3_NUM_REGIMES][MM3_NUM_SENSORS] = {
  /* none    cradle    batt       temp       sal        accel      ptemp      press      speed      mag */
  {  0UL,    0UL,      0UL,       0UL,       0UL,       0UL,       0UL,       0UL,       0UL,       0UL     }, /* 0 - all off  */
  {  0UL,    0UL,      1024UL,    1024UL,    1024UL,    51UL,      1024UL,    1024UL,    1024UL,    51UL    }, /* 1 - main regime */
  {  0UL,    0UL,      1024UL,    1024UL,    1024UL,    1024UL,    1024UL,    1024UL,    1024UL,    1024UL  }, /* 2 - all sensors once/sec */
  {  0UL,    0UL,      102UL,     0UL,       0UL,       102UL,     0UL,       0UL,       0UL,       0UL     }, /* 3 - batt and accel only, 10Hz */
  {  0UL,    0UL,      512UL,     0UL,       0UL,       0UL,       0UL,       0UL,       0UL,       0UL     }, /* 4 */
  {  0UL,    0UL,      0UL,       512UL,     0UL,       0UL,       0UL,       0UL,       0UL,       0UL     }, /* 5 */
  {  0UL,    0UL,      0UL,       0UL,       512UL,     0UL,       0UL,       0UL,       0UL,       0UL     }, /* 6 */
  {  0UL,    0UL,      0UL,       0UL,       0UL,       51UL,      0UL,       0UL,       0UL,       0UL     }, /* 7 - accel, 20 Hz */
  {  0UL,    0UL,      0UL,       0UL,       0UL,       0UL,       512UL,     0UL,       0UL,       0UL     }, /* 8 */
  {  0UL,    0UL,      0UL,       0UL,       0UL,       0UL,       0UL,       512UL,     0UL,       0UL     }, /* 9 */
  {  0UL,    0UL,      0UL,       0UL,       0UL,       0UL,       0UL,       0UL,       512UL,     0UL     }, /* 10 */
  {  0UL,    0UL,      0UL,       0UL,       0UL,       0UL,       0UL,       0UL,       0UL,       51UL    }, /* 11 - mag, 20Hz */
  {  0UL,    0UL,      51UL,	  51UL,	     51UL,      51UL,      51UL,      51UL,      51UL,      51UL    }, /* 12 - all sensors 20 Hz */
  {  0UL,    0UL,      102UL,     102UL,     102UL,     102UL,     102UL,     102UL,     102UL,     102UL   }, /* 13 - all sensors 10 Hz */
  {  0UL,    0UL,      10240UL,   1024UL,    0UL,       51UL,      0UL,       0UL,       51UL,      51UL    }, /* 14 - testing */
  {  0UL,    0UL,      0UL,       0UL,       0UL,       204UL,     0UL,       0UL,       0UL,       204UL   }, /* 15 */
};

#endif
