/*
 * panic codes.
 */


#ifndef __PLATFORM_PANIC_H__
#define __PLATFORM_PANIC_H__

#include <panic.h>

#define PANIC_HC_START 16

/*
 * KERN:	core kernal  (in panic.h)
 * TIME:        timing system panic
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
 * PWR:         power subsystem
 * RADIO:       radio driver issues.
 * TAGNET:      comm stack
 */

typedef enum panic_codes {
  /*
   * these start at PANIC_HC_START (16).  They are hardcoded to be
   * very very explicit about it.  They get are externally visibile
   * when things crash.
   *
   * DO NOT RENUMBER.  Its a pain.
   */
  __pcode_time          = 16,
  __pcode_adc           = 17,
  __pcode_sd            = 18,
  __pcode_fs            = 19,
  __pcode_dm            = 20,
  __pcode_im            = 21,
  __pcode_ss            = 22,
  __pcode_ss_recov      = 23,
  __pcode_gps           = 24,
  __pcode_misc          = 25,
  __pcode_sns           = 26,
  __pcode_pwr           = 27,
  __pcode_radio         = 28,
  __pcode_tagnet        = 29,

  __pcode_exc           = 0x70,
  __pcode_kern          = 0x71,
  __pcode_dvr           = 0x72,

} panic_code_t;

#define PANIC_TIME      __pcode_time
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

#define PANIC_EXC       __pcode_exc
#define PANIC_KERN      __pcode_kern
#define PANIC_DVR       __pcode_dvr

#endif /* __PLATFORM_PANIC_H__ */
