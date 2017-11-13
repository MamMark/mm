/*
 * panic codes.
 */


#ifndef __PLATFORM_PANIC_H__
#define __PLATFORM_PANIC_H__

#include <panic.h>

/*
 * KERN:	core kernal  (in panic.h)
 * TIMING:      timing system panic
 * ADC:		Analog Digital Conversion subsystem (AdcP.nc)
 * SD:          Disk
 * FS:          File System
 * DM:          dblk manager
 * IM:          image manager
 * SS:          Stream Storage
 * SS_RECOV:    Stream Storage recovery mode ???
 * GPS:         GPS subsystem
 * MISC:
 * SNS:         SeNsor Subsystem (SNS)
 */

enum panic_codes {
  __pcode_timing = PANIC_HC_START,		/* 0x10, see panic.h */
  __pcode_adc,
  __pcode_sd,
  __pcode_fs,
  __pcode_dm,
  __pcode_im,
  __pcode_ss,
  __pcode_ss_recov,
  __pcode_gps,
  __pcode_misc,
  __pcode_sns,
  __pcode_pwr,
  __pcode_radio,
  __pcode_tagnet,
};

#define PANIC_TIMING    __pcode_timing
#define PANIC_ADC       __pcode_adc
#define PANIC_SD        __pcode_sd
#define PANIC_FS        __pcode_fs
#define PANIC_DM        __pcode_dm
#define PANIC_IM        __pcode_im
#define PANIC_SS        __pcode_ss
#define PANIC_SS_RECOV  __pcode_ss_recov
#define PANIC_GPS       __pcode_gps
#define PANIC_MISC      __pcode_misc
#define PANIC_SNS       __pcode_sns
#define PANIC_PWR       __pcode_pwr
#define PANIC_RADIO     __pcode_radio
#define PANIC_TAGNET    __pcode_tagnet

#endif /* __PLATFORM_PANIC_H__ */
