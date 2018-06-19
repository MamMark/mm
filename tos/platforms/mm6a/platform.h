/* No platform_bootstrap() needed,
 * since memory system doesn't need configuration and
 * the processor mode neither.
 * (see TEP 107)
 */

/*
 * REQUIRE_PLATFORM:    force Platform wiring (usecsRaw, etc)
 * REQUIRE_PANIC:       force Panic wiring in all modules that use panic
 *                      no default Panic
 *
 * TRACE_MICRO:         Trace timestamps in usecs vs. msecs
 * TRACE_USE_PLATFORM:  Trace use Platform.usecsRaw for timestamping
 *
 * HANDLER_FAULT_WAIT:  default exception handlers should finish in a
 *                      busy wait.
 * MEMINIT_STOP:        cause memory initilization to not be done (hangs)
 *                      so one can poke around at memory.
 *
 * TRACE_VTIMERS        set to trace virtual timers.
 *
 * TRACE_TASKS          set to trace task laucnches
 * TRACE_TASKS_USECS    set to low level usec timestamp function
 */

#ifndef __PLATFORM_H__
#define __PLATFORM_H__

#define GO_GATE
#define REQUIRE_PLATFORM
#define REQUIRE_PANIC

#define IRQ_DEFAULT_PRIORITY    4
#define IRQ_LOW_PRIORITY        7

#define GPS_IRQN                EUSCIA0_IRQn
#define GPS_IRQ_PRIORITY        2

#define RADIO_IRQN              EUSCIB2_IRQn
#define RADIO_IRQ_PRIORITY      3

// #define HANDLER_FAULT_WAIT
// #define PANIC_GATE
// #define CATCH_STRANGE

#define PWR_CHECK_TIME (10*1024)

//#define TRACE_MICRO
#define TRACE_USE_PLATFORM
//#define MEMINIT_STOP

#define TRACE_VTIMERS
#define TRACE_TASKS
#define TRACE_TASKS_USECS __platform_usecs_raw()

extern uint32_t __platform_usecs_raw();

#define TRACE_RESOURCE
#define FS_ENABLE_ERASE
#define IM_ERASE_ENABLE
#define DBLK_ERASE_ENABLE

#define SI446x_HW_CTS

#define CRASH_STACK_WORDS 128

/*
 * TagNet uses a single byte length at the start of its header.  This is
 * also what the si446x radio expects.  However, the radio length doesn't
 * include the frame_length.  Above the phy layer we use the frame_length
 * to indicate the full length of the packet.  So the maximum phy length
 * can be 0xFE giving a full packet length of 0xFF.
 *
 * We simply use 250 because it is a nice round number (go figure).  We
 * then have 250 bytes of payload, 4 bytes of header, yielding 254 bytes.
 * Which on the wire looks like a length of 0xFD.  But above the PHY layer
 * looks like 0xFE.
 */
#define TOSH_DATA_LENGTH 250
#define GPS_EAVESDROP


/*
 * platform.h is one of the first files included.
 * pull in any compiler definitions we may need.
 */
#include <msp432.h>
#include <panic.h>
#include <platform_panic.h>

/*
 * define PLATFORM_TAn_ASYNC TRUE if the timer is being clocked
 * asyncronously with respect to the main system clock
 */

/*
 * TA0 is Tmicro, clocked by TA0 <- SMCLK/8 <- DCOCLK/2
 * TA1 is Tmilli, clocked by ACLK 32KiHz (async)
 */
#define PLATFORM_TA1_ASYNC TRUE

#endif // __PLATFORM_H__
