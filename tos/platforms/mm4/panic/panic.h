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

#define P_BLK_SIZE 2
#define PANIC_WARN_FLAG 0x80

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

#define PANIC_KERN	0x01
#define PANIC_ADC	0x02
#define PANIC_MISC	0x03
#define PANIC_COMM	0x04
#define PANIC_MS	0x05
#define PANIC_SS	0x06
#define PANIC_SS_RECOV	0x07
#define PANIC_GPS	0x08

#ifdef notdef
#define PANIC_SNS	0x09
#define PANIC_PWR	0x0A
#endif

#endif /* __PANIC_H__ */
