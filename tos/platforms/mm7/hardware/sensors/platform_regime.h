/*
 * Copyright (c) 2019-2021, Eric B. Decker
 * All rights reserved.
 */

#include "regime_ids.h"
#include <sensor_config.h>

#ifndef PLATFORM_REGIME_H
#define PLATFORM_REGIME_H

/*
 * All entries in binary microseconds (uis).
 */
const uint32_t sns_period_table[RGM_MAX_REGIME + 1][RGM_ID_MAX + 1] = {

/*              periodic  -  ms/bms            |  complex - period/odr (us)                            */
/* none   batt      tmpPX     sal       speed     accel       gyro        mag         press            */
 { 0UL,   0UL,      0UL,      0UL,      0UL,      0UL,        0UL,        0UL,        0UL,        },  /* 0 - all off  */
 { 0UL,   BMS_MIN,  BMS_MIN,  BMS_SEC,  BMS_SEC,  SNS_12D5HZ, 0UL,        SNS_10HZ,   SNS_1HZ,    },  /* 1 - main regime */
 { 0UL,   BMS_SEC,  BMS_MIN,  BMS_SEC,  BMS_SEC,  SNS_1D6HZ,  0UL,        SNS_10HZ,   SNS_1HZ,    },  /* 2 - most sensors slowest rate, 1/sec */
 { 0UL,   BMS_MIN,  0UL,      0UL,      0UL,      SNS_12D5HZ, 0UL,        0UL,        0UL,        },  /* 3 - batt and accel only, 10Hz */
 { 0UL,   BMS_MIN,  0UL,      0UL,      0UL,      0UL,        0UL,        0UL,        0UL,        },  /* 4 * */
 { 0UL,   0UL,      BMS_MIN,  0UL,      0UL,      0UL,        0UL,        0UL,        0UL,        },  /* 5 */
 { 0UL,   0UL,      0UL,      512UL,    0UL,      0UL,        0UL,        0UL,        0UL,        },  /* 6 */
 { 0UL,   0UL,      0UL,      0UL,      0UL,      SNS_26HZ,   0UL,        0UL,        0UL,        },  /* 7 - accel, 20 Hz */
 { 0UL,   0UL,      0UL,      0UL,      0UL,      0UL,        0UL,        0UL,        0UL,        },  /* 8 */
 { 0UL,   0UL,      0UL,      0UL,      0UL,      0UL,        0UL,        0UL,        SNS_10HZ,   },  /* 9 */
 { 0UL,   0UL,      0UL,      0UL,      512UL,    0UL,        0UL,        0UL,        0UL,        },  /* 10 */
 { 0UL,   0UL,      0UL,      0UL,      0UL,      SNS_1D6HZ,  0UL,        SNS_20HZ,   0UL,        },  /* 11 - mag, 20Hz */
 { 0UL,   51UL,     51UL,     51UL,     51UL,     SNS_26HZ,   0UL,        SNS_20HZ,   SNS_25HZ,   },  /* 12 - all sensors 20 Hz */
 { 0UL,   102UL,    102UL,    102UL,    102UL,    SNS_12D5HZ, 0UL,        0UL,        SNS_10HZ,   },  /* 13 - all sensors 10 Hz */
 { 0UL,   BMS_MIN,  BMS_MIN,  BMS_SEC,  0UL,      SNS_12D5HZ, SNS_12D5HZ, SNS_10HZ,   SNS_1HZ,    },  /* 14 - testing */
 { 0UL,   0UL,      0UL,      0UL,      0UL,      SNS_26HZ,   0UL,        SNS_20HZ,   0UL,        },  /* 15 - accel, mag, 20 Hz */
};

#endif
