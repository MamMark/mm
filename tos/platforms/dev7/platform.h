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

/*
 * define different MSP432_LFXT_DRIVE{,_INITIAL} prior to pulling
 * in platform_clk_defs.h
 */
#define MSP432_LFXT_DRIVE 0
#define MSP432_LFXT_DRIVE_INITIAL 2

#define GO_GATE
#define REQUIRE_PLATFORM
#define REQUIRE_PANIC

#define IRQ_DEFAULT_PRIORITY    4
#define IRQ_LOW_PRIORITY        7

/*
 * dev7 doesn't use EUSCI interrupts
 * rather it uses a TXRDY interrupt to run the gps
 * spi stream.
 *
 * GPS_IRQN and GPS_IRQ_PRIORITY are maintained for backward compatibility
 * with previous GPS implementations.  When the mm6a and dev6a are full
 * deprecated this can be removed and mm/PlatformP can be appropriately
 * modified.
 */
#define GPS_IRQN                EUSCIA1_IRQn
#define GPS_IRQ_PRIORITY        4

#define RADIO_IRQN              EUSCIB2_IRQn
#define RADIO_IRQ_PRIORITY      3

// #define HANDLER_FAULT_WAIT
// #define PANIC_GATE
// #define CATCH_STRANGE

//#define TRACE_MICRO
#define TRACE_USE_PLATFORM
//#define MEMINIT_STOP

#define TRACE_VTIMERS
#define TRACE_TASKS
#define TRACE_TASKS_USECS __platform_usecsRaw()

extern uint32_t __platform_usecsRaw();

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
#define DOCK_EAVESDROP

/*
 * GPS_DEBUG_DEV wraps gps debugging that uses TELL and EXC to communicate
 * changes in the gps subsystem on a DEV boards that have TELL and EXC
 * i/o pins defined.
 */
#define GPS_DEBUG_DEV

/*
 * The LSM6DSOX includes an I2C sensor hub hanging off the back end.  External
 * or Internal pull up resisters are needed to make the I2C bus work.  Depends
 * on the h/w implementation.
 *
 * The DEV7 can use the ST lsm6dsox based development boards, STEVAL-MKI197V1 and
 * the STEVAL-MKI217V1.
 *
 * The 217 includes the LIS2MDL mag and includes external pull up resistors.
 * (Needed to get the open drain I2C bus to work).
 *
 * The 197 uses just a LSM6DSOX with no chips connected to the sensor hubs.  There
 * are no pull up reistors.  If we are using/testing I2C stuff, we must turn on
 * the internal pull up resistors.
 */

// #define PLATFORM_LSM6_I2C_PU_EN

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

/* we use 6 bytes from the random number the msp432 provides */
#define PLATFORM_SERIAL_NUM_SIZE 6

#endif // __PLATFORM_H__
