/**
 * Basic defines for tmp102/tmp112 --> tmp1x2 family.
 * See p. 7 and on of tmp102/tmp112 data sheets.
 *
 * tmp112 is an extended range version of the 102.  Interface is the
 * same.
 *
 *  @author Eric B. Decker <cire831@gmail.com>
 */

#ifndef __TMP1X2_H__
#define __TMP1X2_H__

#define TMP1X2_TEMP	0
#define TMP1X2_CONFIG	1
#define TMP1X2_TLOW	2
#define TMP1X2_THIGH	3

/*
 * delay from power on to first conversion should be available
 * In ms.
 */
#define TMP1X2_PWR_ON_DELAY 35

/*
 * config register bits
 */
#define TMP1X2_CONFIG_ONESHOT	0x8000
#define TMP1X2_CONFIG_RES_MASK	0x6000
#define TMP1X2_CONFIG_RES_3	0x6000
#define TMP1X2_CONFIG_FLT_MASK	0x1800
#define TMP1X2_CONFIG_FAULT_1	0x0000
#define TMP1X2_CONFIG_FAULT_2	0x0800
#define TMP1X2_CONFIG_FAULT_4	0x1000
#define TMP1X2_CONFIG_FAULT_6	0x1800
#define TMP1X2_CONFIG_POLARITY	0x0400
#define TMP1X2_CONFIG_TM	0x0200
#define TMP1X2_CONFIG_SD	0x0100

/* byte 2, lsb */
#define TMP1X2_CONFIG_8HZ	0x00c0
#define TMP1X2_CONFIG_4HZ	0x0080
#define TMP1X2_CONFIG_1HZ	0x0040
#define TMP1X2_CONFIG_25HZ	0x0000
#define TMP1X2_CONFIG_AL	0x0020
#define TMP1X2_CONFIG_EM	0x0010

#endif	/* __TMP1X2_H__ */
