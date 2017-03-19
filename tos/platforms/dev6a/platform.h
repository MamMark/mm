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
 * PANIC_WIGGLE:        enable panic code to emit pcode and where on the
 *                      exception wiggle line.
 */

#define REQUIRE_PLATFORM
#define REQUIRE_PANIC
//#define TRACE_MICRO
//#define TRACE_USE_PLATFORM
#define HANDLER_FAULT_WAIT
#define MEMINIT_STOP
#define PANIC_WIGGLE

#define SI446x_HW_CTS

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
