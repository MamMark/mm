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
#ifdef notdef
//  PANIC_KERN = PANIC_HC_START,		/* 0x10, see panic.h */
#endif
//  PANIC_KERN = 0x10,
#ifdef notdef
  PANIC_ADC,
  PANIC_MISC,
  PANIC_COMM,
  PANIC_MS,
  PANIC_SS,
  PANIC_SS_RECOV,
#endif
  PANIC_GPS,

#ifdef notdef
  PANIC_SNS,
  PANIC_PWR,
#endif
};

#endif /* __PLATFORM_PANIC_H__ */
