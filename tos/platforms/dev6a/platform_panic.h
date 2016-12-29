/*
 * panic codes.
 */


#ifndef __PLATFORM_PANIC_H__
#define __PLATFORM_PANIC_H__

#include "panic.h"

/*
 * KERN:	core kernal  (in panic.h)
 * TIMING:      timing system panic
 * ADC:		Analog Digital Conversion subsystem (AdcP.nc)
 * MISC:
 * COMM:	communications subsystem
 */

enum {
  PANIC_TIMING = PANIC_HC_START,		/* 0x10, see panic.h */
  PANIC_ADC,
  PANIC_MS,
  PANIC_SS,
  PANIC_SS_RECOV,
  PANIC_GPS,
  PANIC_MISC,
  PANIC_COMM,
  PANIC_SNS,
};

#endif /* __PLATFORM_PANIC_H__ */
