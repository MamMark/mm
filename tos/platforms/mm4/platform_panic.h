/*
 * panic codes.
 */


#ifndef __PLATFORM_PANIC_H__
#define __PLATFORM_PANIC_H__

#include "panic.h"

/*
 * KERN:	core kernal
 * ADC:		Analog Digital Conversion subsystem (AdcP.nc)
 * MISC:
 * COMM:	communications subsystem
 * MS:		Mass Storage (FileSystemP, SD)
 * SS:		Stream Storage, hard fail
 * SS_RECOV:	Stream Storage, recoverable
 * GPS:		gps subsystem
 */

enum {
  PANIC_ADC  = PANIC_HC_START,          /* 0x70, see panic.h */
  PANIC_MISC,
  PANIC_COMM,
  PANIC_MS,
  PANIC_SS,
  PANIC_SS_RECOV,
  PANIC_GPS,

#ifdef notdef
  PANIC_SNS,
  PANIC_PWR,
#endif
};

#endif /* __PLATFORM_PANIC_H__ */
