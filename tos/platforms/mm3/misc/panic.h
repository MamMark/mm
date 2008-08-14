/* $Id: panic.h,v 1.24 2007/07/06 23:27:59 cire Exp $
 *
 * panic codes.
 *
 * If the high bit is set this denotes a warning.  Simply
 * by convention.  If Panic.panic is called the system will
 * crash, do a crash dump, and then restart.  If Panic.warn
 * is called a panic record is written to the SD and the
 * system continues after the caller does what ever it needs
 * to to recover.
 */


#ifndef __PANIC_H__
#define __PANIC_H__

#define PANIC_WARN_FLAG 0x80

#define PANIC_KERN	1
#define PANIC_ADC	2
#define PANIC_MISC	3
#define PANIC_COMM	4
#define PANIC_SD	5
#define PANIC_SS	6
#define PANIC_GPS	7

#ifdef notdef
#define PANIC_SNS	6
#define PANIC_PWR	7
#endif

#endif /* __PANIC_H__ */
