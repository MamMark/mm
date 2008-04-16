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

#define PANIC_ADC	1
#define PANIC_MISC	2
#define PANIC_COMM	3
#define PANIC_SD	4
#define PANIC_SS	5

#ifdef notdef
#define PANIC_KERN	1
#define PANIC_FX	2
#define PANIC_US1	3
#define PANIC_SD	4
#define PANIC_MS	5
#define PANIC_SNS	6
#define PANIC_PWR	7
#define PANIC_MSG	8
#define PANIC_TIMER	9
#endif

#endif /* __PANIC_H__ */
