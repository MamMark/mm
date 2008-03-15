/*
 * Copyright (c) 2008, Eric B. Decker
 * All rights reserved.
 */

#ifndef REGIME_H
#define REGIME_H

#include "sensors.h"

#define SNS_DEFAULT_REGIME		2
#define SNS_MAX_REGIME			5
#define MM3_NUM_REGIMES			(SNS_MAX_REGIME + 1)
  
/*
 * All times in milliseconds.
 */
const uint32_t sns_period_table[MM3_NUM_REGIMES][MM3_NUM_SENSORS] = {
  /* none    bat        temp       sal        accel      ptemp      press      speed      mag */
  {  0UL,    0UL,       0UL,       0UL,       0UL,       0UL,       0UL,       0UL,       0UL     }, /* 0 - all off  */
  {  0UL,    1000UL,    1000UL,    1000UL,    50UL,      1000UL,    1000UL,    1000UL,    50UL    }, /* 1 - main regime */
  {  0UL,    1000UL,    1000UL,    1000UL,    1000UL,    1000UL,    1000UL,    1000UL,    1000UL  }, /* 2 - all sensors once/sec */
  {  0UL,    1000UL,    0UL,       0UL,       1000UL,    0UL,       0UL,       0UL,       0UL     }, /* 3 - batt and accel only */
  {  0UL,    0UL,       0UL,       0UL,       1000UL,    0UL,       0UL,       0UL,       0UL     }, /* 4 - accel only */
  {  0UL,    0UL,	0UL,	   1UL,	      0UL,       0UL,       0UL,       0UL,       0UL  },    /* 5 - testing */
};

#endif
