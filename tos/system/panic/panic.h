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
 * pcodes start at PANIC_HC_START.  (HC = hard coded)
 *
 * Automatic pcodes start at 0 and go to 15 (0xf).  There is
 * no checking for overrun with PANIC_HC_START.  Automatics
 * are generated using unique(UQ_PANIC_SUBSYS).
 */
#define PANIC_HC_START 16

/*
 * main system hardcoded (HC) pcodes start at 0x70
 *
 * EXC          exception handler
 * KERN         kernel panics
 * DVR          undifferentiated driver panics
 */

enum {
  __pcode_exc  = 0x70,
  __pcode_kern = 0x71,
  __pcode_dvr  = 0x72,
};

#define PANIC_EXC  __pcode_exc
#define PANIC_KERN __pcode_kern
#define PANIC_DVR  __pcode_dvr

/* the argument type for panics */
typedef unsigned int parg_t;

/*
 * Various signatures for the different pieces of Panic information
 */
#define PANIC_INFO_SIG
#define PANIC_CPU_SIG

#endif /* __PANIC_H__ */
