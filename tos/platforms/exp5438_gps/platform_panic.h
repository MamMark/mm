/*
 * panic codes.
 */


#ifndef __PLATFORM_PANIC_H__
#define __PLATFORM_PANIC_H__

#include "panic.h"

/*
 * KERN:	core kernal (defined in panic.h)
 * ADC:		Analog Digital Conversion subsystem (AdcP.nc)
 * MISC:
 * COMM:	communications subsystem
 * MS:		Mass Storage (FileSystemP, SD)
 * SS:		Stream Storage, hard fail
 * SS_RECOV:	Stream Storage, recoverable
 * GPS:		gps subsystem
 */

enum {
  __pcode_gps = __pcode_HC_START,		/* 0x10, see panic.h */

#ifdef notdef
  __pcode_adc,
  __pcode_misc,
  __pcode_comm,
  __pcode_ms,
  __pcode_ss,
  __pcode_ss_recov,
  __pcode_sns,
  __pcode_pwr,
#endif
};

#define PANIC_GPS __pcode_gps

#endif /* __PLATFORM_PANIC_H__ */
