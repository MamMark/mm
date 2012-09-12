/*
 * panic codes.
 *
 * If the high bit is set this denotes a warning.  Simply
 * by convention.  If Panic.panic is called the system will
 * crash, do a crash dump, and then restart.  If Panic.warn
 * is called a panic record is written to the SD and the
 * system continues after the caller does what ever it needs
 * to recover.
 */


#ifndef __PANIC_H__
#define __PANIC_H__

#define PANIC_WARN_FLAG 0x80

/*
 * pcodes are used to denote what subsystem failed.  See
 * (main tree) tos/interfaces/Panic.nc for more details.
 *
 * Pcodes can be defined automatically using unique or
 * can be hard coded.   To avoid collisions, hard coded
 * pcodes start at PANIC_HC_START.
 */
#define PANIC_HC_START 16

#endif /* __PANIC_H__ */
