/*
 * Copyright (c) 2012, 2014-2016 Eric B. Decker
 * All rights reserved.
 *
 * @author Eric B. Decker (cire831@gmail.com)
 * @date 23 May 2012
 * @updated Feb 9, 2014
 * @updated Mar 23, 2016 ported to mm5a/b
 * @updated June 2016, pre-production code for GPS
 *  back on hold, new gps chip eval
 *
 * M10478 GSD4e driver, dedicated 5438 usci spi port
 * originally based on dedicated 2618 usci uart port sirf3 driver.
 *
 * Feb 16, 2014, Antenova M10478 prototype contains version:
 *     GSD4e_4.1.2-P1 R+ 11/15/2011 319-Nov 15 2011-23:04:55.GSD4e..2
 * Jun 11, 2016: Antenova M10478
 *     GSD4e_4.1.2-P1 R+ 11/15/2011 319-Nov 15 2011-23:04:55.GSD4e..2
 *
 * GPSC -> Gps Control
 */

#include "gps.h"
#include "sirf.h"
#include "typed_data.h"

#include "platform_panic.h"

/*
 * The M10478 GSD4e GPS module is interfaced using SPI at 4MHz.  By default
 * it communicates using OSP (One Socket Protocol), SirfBin superset.
 *
 * Since we are communicating using SPI and the gps chip is a SPI slave, it
 * can't send us unsolicited messages.   We always have to be talking to
 * the chip for it to talk to us.
 *
 * There is a provision on the M10478 gps module for a GPIO signal to be used
 * as a Message Awaiting signal but it is currently unknown how to enable that.
 * Also we use the GPS in a strictly command/response mode.  We turn off periodic
 * messages and explicitly ask for messages.
 *
 * To enable being able to observe all GPS communications we write records into
 * the SD (using COLLECT).  This means we need a structure that handles ping ponging
 * between the SD tasks and the GPS tasks.  All GPS communications is done at task
 * level so that when a complete packet is observed, we can switch over to the
 * GPSMsg task to handle it and pass it on to the Collector.
 *
 * M10478 GSD4e power up observations:
 *
 * o When first powered up, one must pulse ON_OFF to wake the chip.  M10478 documentation
 *   states pulse must be held for > 90us.  We've observed ON_OFF edge up -> AWAKE takes
 *   between 130-145us.
 *
 * o If we try to talk to the chip too early after being woken up it fails.   Returns
 *   nothing but zeros.  DT_GPS_ON_OFF_PULSE_WIDTH controls how long the ON_OFF is
 *   asserted.  It also controls when we first try to look at the chips output fifo
 *   via the SPI.
 *
 *   < 70ms     hangs
 *   < 120ms    get idles (a7 b4)
 *   120ms +    see oktosend (mid 18)
 *   225ms      see oktosend (mid 18) + Nav_Complete (mid 47)
 *
 * 200ms seems about right.
 *
 * The driver needs to function so as to keep the gps TX fifo (gps to cpu) empty.
 * When the gps is first powered on it will be configured to be sending messages
 * periodically.  The chip is a SPI slave and so doing async I/O into the fifos is
 * stupid.  This basically means the CPU has to poll to see if anything interesting
 * is in the fifos.  So instead we turn off all periodic messages and ask for the
 * current status when we need to know something.
 *
 * ORG4472 info (from observations, Fastrax and ORG docs):
 *
 * On initial power on (system power up), the gps can take anywhere from 300ms upwards to
 * 5 secs (in cold conditions) to power up the RTC module.  (Info from the Fastrax, org
 * data sheet).  Normally, we keep power applied so this shouldn't be an issue.  Normal
 * turn on (initiated by on_off toggle), takes at least 74ms (observed).   Documentation says
 * 20ms but that is wrong.  We pulse on_off for 100 ms to bring the chip out of hibernate
 * so that should cover it.   We will see initial turn on problems (given the RTC takes
 * 300ms upwards to 5 seconds to turn on).   Unclear if this effects the operation of
 * the SPI h/w.   We need to have the wakeup state machine handle this.   If the initial attempt
 * to communicate fails, then take CS down, possibly reset, and delay longer.
 *
 * Startup data from ORG4472 datasheet:
 *
 * RTC startup time: 300ms (dT1, delta T sub 1)
 * T_rtc: 30.5176us (1/32768 Hz)
 * Pwr stable: max 8 * t_rtc + dT1 = ~ 301ms
 *
 * on_off low:  3 * t_rtc -> 100us
 * on_off High: 3 * t_rtc -> 100us
 * dT3, startup sequencing: 1024 * t_rtc -> ~ 32ms (don't know what this is referencing)
 * on_off -> wakeup high: 6 * t_rtc -> 184 us
 * on_off -> arm start: 2130 * t_rtc -> 65ms
 * dT7, main pwr seq start: 300 * t_rtc -> ~ 10ms.
 *
 * what does this all mean....?   not sure.
 *
 * NMEA start up:
 *      PULSE_ON ->   (go_sirf_bin) OSP_WAIT ->  (config)
 *              time
 *
 * OSP (normal) start up:
 *      PULSE_ON -> (config)
 *
 * unusual state: (reset and resume normal power up)
 *      RESET_PULSE -> RESET_WAIT -> PULSE_ON
 *                 time          time
 *
 * Power down:
 */

/*
 * States may have multiple parts, ie. FIRST, FIRST_A, FIRST_B, etc.  This
 * denotes that i/o from the gps chip may need multiple processing sections
 * to handle task switches to other tasks that are working with the gps
 * messages.
 */
typedef enum {
  GPSC_OFF  = 0,
  GPSC_FAIL = 1,
  GPSC_RESET_PULSE,             // pulsing reset pin
  GPSC_RESET_WAIT,              // time after reset to wait
  GPSC_PULSE_ON,		// turning on
  GPSC_FIRST,                   // first msg, what mode are we in
  GPSC_OSP_WAIT,		// wait for NMEA -> OSP switch
  GPSC_CONFIG,                  // start up, configuration commands
  GPSC_SW_VER,                  // ask for sw_ver (try to talk)
  GPSC_SW_VER_FINI,
  GPSC_POLL_NAV,		// just turned on, see how we are doing.

  GPSC_ON,                      // waiting for next cycle

  GPSC_SHUTDOWN_CLEAN,          // shutting down, clean out pipes
  GPSC_PULSE_OFF,		// trying pulse to turn off
  GPSC_PULSE_OFF_WAIT,		// give it time.
  GPSC_SHUTDOWN_MSG,
  GPSC_SHUTDOWN_MSG_WAIT,

  GPSC_BACK_TO_NMEA,

  GPSC_FIRST_A = 0x80,          // intermediate states, do not log
  GPSC_FIRST_B,
  GPSC_CONFIG_A,
  GPSC_CONFIG_B,
  GPSC_SW_VER_A,
  GPSC_SW_VER_B,
  GPSC_SW_VER_C,
  GPSC_SW_VER_FINI_A,
  GPSC_CONFIG_C,
  GPSC_CONFIG_D,
  GPSC_POLL_NAV_A,
  GPSC_POLL_NAV_B,
  GPSC_POLL_NAV_C,
  GPSC_ON_A,
  GPSC_ON_B,
  GPSC_SHUTDOWN_CLEAN_A,
  GPSC_SHUTDOWN_CLEAN_B,
  GPSC_PULSE_OFF_WAIT_A,
  GPSC_PULSE_OFF_WAIT_B,
  GPSC_SHUTDOWN_MSG_A,
  GPSC_SHUTDOWN_MSG_WAIT_A,
  GPSC_SHUTDOWN_MSG_WAIT_B,
  GPSC_SHUTDOWN_MSG_WAIT_C,
} gpsc_state_t;

#define GPSC_NO_LOG     0x80

typedef enum {
  GPSW_NONE = 0,
  GPSW_TIMER,
  GPSW_COMM_WAKE,
  GPSW_COMM_TASK,
  GPSW_SEND_DONE,
  GPSW_MSG_BOUNDARY,
  GPSW_START,
  GPSW_STOP,
} gps_where_t;


#ifdef GPS_LOG_EVENTS

typedef struct {
  uint32_t     ts;
  gpsc_state_t gc_state;
  gps_where_t  where;
  uint16_t     g_idx;
} gps_event_t;


#define GPS_MAX_EVENTS 32

gps_event_t g_evs[GPS_MAX_EVENTS];
uint8_t g_nev;			// next gps event

#endif		// GPS_LOG_EVENTS


volatile uint16_t wait_time = 5;
volatile uint32_t g_t0, g_t1;
volatile uint16_t u_t[4];
volatile bool g_flush = TRUE;
uint8_t gps_version[80];

gpsc_state_t    	    gpsc_state; // low level gps driver (controller) state

/* instrumentation */
uint32_t		    gpsc_boot_time;		// time it took to boot.
uint32_t		    gpsc_cycle_time;		// time last cycle took
uint32_t		    gpsc_max_cycle;		// longest cycle time.

/*
 * control structure for incoming bytes from the gps.
 * Blocks of data from the gps are variable so we need both
 * an index and remaining counts.
 */
typedef struct {
  uint16_t index;			/* where the next char is */
  uint16_t remaining;			/* how many are left */
  uint8_t buf[BUF_INCOMING_SIZE];
} inbuf_t;

inbuf_t incoming;			/* incoming bytes from gps */


module Gsd4eP {
  provides {
    interface Init;
    interface SplitControl as GPSControl;
  }
  uses {
    interface Timer<TMilli> as GPSTimer;
    interface LocalTime<TMilli>;
    interface Gsd4eInterface as HW;
    interface Panic;
    interface SpiBlock;
    interface SpiByte;
    interface GPSMsgS;
    interface StdControl as GPSMsgControl;
//    interface Trace;
//    interface LogEvent;
//    interface Boot;
    interface Platform;
  }
}


implementation {

  enum {
    GPS_CMD_NONE      = 0,              /* no command pending */
    GPS_CMD_TURNON,                     /* turn gps on and start cycling */
    GPS_CMD_TURNOFF,                    /* turn gps off */
  } gps_cmd;


  uint32_t	t_gps_pwr_on;
  uint16_t      t_gps_pwr_on_usecs;
  uint16_t	gpsc_limit;
  bool          gpsc_operational;


  void gpsc_log_state(gpsc_state_t next_state, gps_where_t where) {
#ifdef GPS_LOG_EVENTS
    uint8_t idx;

#ifdef notdef
    if (next_state & GPSC_NO_LOG)
      return;
#endif
    atomic {
      idx = g_nev++;
      if (g_nev >= GPS_MAX_EVENTS)
	g_nev = 0;
      g_evs[idx].ts = call LocalTime.get();
      g_evs[idx].gc_state = next_state;
      g_evs[idx].where = where;
      g_evs[idx].g_idx = call GPSMsgS.eavesIndex();
    }
#endif
  }

  void gpsc_change_state(gpsc_state_t next_state, gps_where_t where) {
    gpsc_log_state(next_state, where);
    gpsc_state = next_state;
  }

  void gps_panic_warn(uint8_t where, uint16_t p) {
    call Panic.warn(PANIC_GPS, where, p, 0, 0, 0);
  }

  void gps_panic(uint8_t where, uint16_t p) {
    call Panic.panic(PANIC_GPS, where, p, 0, 0, 0);
  }


  /*
   * gps_send_block
   *
   * send a block of data to the gps, receive return data
   * set incoming data structures appropriately to reflect
   * how much data is received.
   */
   void gps_send_block(const uint8_t *buf, uint16_t size) {
    if (incoming.remaining)
      gps_panic_warn(1, incoming.remaining);
    if (size > BUF_INCOMING_SIZE)
      gps_panic(2, size);
    call HW.gps_set_cs();
    call SpiBlock.transfer((uint8_t *) buf, incoming.buf, size);
    call HW.gps_clr_cs();
    incoming.index = 0;
    incoming.remaining = size;
  }


  /*
   * process incoming bytes from the gps.
   *
   * return:    number of remaining bytes still to be processed.
   *
   * Effectively, a boolean, TRUE (!= 0) means that the GPS Msg processor
   * is blocked and we must wait until it tells us to resume.
   */

  bool process_incoming() {
    uint16_t num_processed;

    num_processed = call GPSMsgS.processBuffer(&incoming.buf[incoming.index], incoming.remaining);
    incoming.remaining -= num_processed;
    incoming.index += num_processed;
    return (incoming.remaining);
  }


  /*
   * checkIdle
   *
   * Scan the remainder of the incoming buffer for idles.
   *
   * return:	TRUE	nothing remains in the buffer to be processed.
   *		FALSE	buffer has reasonable stuff in it.   process.
   *
   * Update inbuf control structures to jump over any idles we've encountered.
   *
   * The Gsd4e has a two byte idle sequence (not completely sure of the
   * symantics, seems overly complex, but it is what we've got).
   *
   * The IDLE symantics is rather ugly.  But it is what we've got.
   * We are looking for two bytes next to each other.   Either A7B4 or
   * B4A7.   And then repeats.   We don't want to find individual instances
   * of either idle byte as that could be part of the data.  Be
   * paranoid although it probably doesn't matter because of packetization.
   */
  
  bool checkIdle() {
    uint8_t b0, b1;
    uint8_t *ptr;
    uint16_t remaining, index;

    index = incoming.index;
    remaining = incoming.remaining;
    if ((index > BUF_INCOMING_SIZE) || (remaining > BUF_INCOMING_SIZE)) {
      call Panic.warn(PANIC_GPS, 2, index, remaining, 0, 0);
      incoming.index = 0;
      incoming.remaining = 0;
      return TRUE;
    }
    if (!remaining)
      return TRUE;
    ptr = incoming.buf;
    b0 = ptr[index];
    if (b0 == SIRF_SPI_IDLE)
      b1 = SIRF_SPI_IDLE_2;
    else if (b0 == SIRF_SPI_IDLE_2)
      b1 = SIRF_SPI_IDLE;
    else
      return FALSE;
    while (remaining) {
      if (remaining >= 2) {
	if (ptr[index] != b0)
	  break;
	index++; remaining--;
	if (ptr[index] != b1)
	  break;
	index++; remaining--;
      } else {
	/* remaining 1 */
	if (ptr[index] != b0)
	  break;
	index++; remaining--;
      }
    }
    incoming.index = index;
    incoming.remaining = remaining;
    if (remaining)
      return FALSE;
    return TRUE;
  }


  /*
   * gps_mark
   *
   * mark the eavesdrop buffer...
   */
  void gps_mark(uint8_t m) {
    call GPSMsgS.eavesDrop(m);
  }


  /*
   * gps_drain
   *
   * drain the gps outbound (from gps) fifo, process any packets.
   */
  void gps_drain(uint16_t limit, bool pull) {
    uint16_t b_count;

    call GPSMsgS.setDraining(TRUE);
    if (limit == 0)
      limit = 2047;
    b_count = 0;
    while (1) {
      gps_send_block(osp_idle_block, BUF_INCOMING_SIZE);
      if (process_incoming())
        gps_panic(4, 0);
      if (!pull && checkIdle())
	break;
      b_count += BUF_INCOMING_SIZE;
      if (b_count > limit)
	break;
    }
    if (pull)				/* if pulling, then we always hit max b_count */
      return;				/* never panic. */
    if (limit >= 2047 && b_count > limit)
      gps_panic_warn(5, b_count);
    call GPSMsgS.setDraining(FALSE);
  }


  /*
   * shut down gps.
   */
  void driver_stop(gps_where_t w) {
    gpsc_change_state(GPSC_OFF, w);
    call GPSTimer.stop();
    if (gps_cmd) {
      gps_cmd = GPS_CMD_NONE;
      signal GPSControl.stopDone(SUCCESS);
    }
//  call LogEvent.logEvent(DT_EVENT_GPS_OFF, 0);
  }


  /*
   * gps_comm_task: Handle talking to the gps via SPI.
   *
   * All talking via the SPI port to/from the GPS is handled by
   * the gps_comm_task.  This allows packet processing to be interleaved
   * with packets being processed by other parts of the system.
   *
   * In general, any transmission to the GPS can result in bytes coming from
   * the GPS that need to get processed.  So any gps_send_block needs
   * to be followed by a process_incoming.  But process_incoming (which hands
   * bytes to the GPSMsg processor) can result in a complete packet being
   * handed over to another task for processing (the collection buffer is busy).
   * So if process_incoming blocks (returns TRUE) then we must stay in a
   * transitory state waiting (we actually don't run) waiting for a
   * GPSMsgS.resume indicating that the collection buffer is now free and we
   * can start pushing bytes at the GPSMsg processor again.
   *
   * These transitory, I/O states, are indicated by _A, _B, etc.
   */
  task void gps_comm_task() {
    gpsc_state_t cur_gps_state;
    bool blocked;

    cur_gps_state = gpsc_state;
    gpsc_change_state(cur_gps_state, GPSW_COMM_WAKE);
    switch (cur_gps_state) {
      default:
      case GPSC_FAIL:
	gps_panic(6, cur_gps_state);
	return;

      case GPSC_FIRST:
	/*
	 * We should have the 1st message after coming out of hibernate.
	 * The expected 1st message is OkToSend (either NMEA or SirfBin
	 * variety).  If NMEA, we want to reconfigure.
	 *
	 * We have observed that immediately after the PulseOn (100ms after
	 * sending on_off high) we should have an OkToSend, either flavor.
	 *
	 * Check which flavor and change state accordingly.
         *
         * process_incoming will change state of incoming but incoming.buf
         * will still be valid.
	 */

	gps_send_block(osp_idle_block, BUF_INCOMING_SIZE);
        /* fall through into FIRST_A to process incoming bytes */

      case GPSC_FIRST_A:
        if (process_incoming()) {
          gpsc_change_state(GPSC_FIRST_A, GPSW_COMM_TASK);
          return;
        }
        /* we rely on incoming.buf being untouched */
        if (memcmp(incoming.buf, osp_oktosend, sizeof(osp_oktosend)) == 0) {
          /*
           * Already in OSP mode.
           */
          gpsc_change_state(GPSC_CONFIG, GPSW_TIMER);
          post gps_comm_task();
          return;
	}
        if (memcmp(incoming.buf, nmea_oktosend, sizeof(nmea_oktosend)) != 0) {
          /* not recognized */
          gps_panic(7, incoming.buf[0]);
          return;
        }

        /*
         * looks like nema, reconfigure
         *
         * got nema_oktostart, send nmea_go_sirf_bin.  The chip then takes
         * some time to reconfigure.
         */
        gps_send_block(nmea_go_sirf_bin, sizeof(nmea_go_sirf_bin));

        /* fall through to FIRST_B */

      case GPSC_FIRST_B:
        if (process_incoming()) {
          gpsc_change_state(GPSC_FIRST_B, GPSW_COMM_TASK);
          return;
        }
        gpsc_change_state(GPSC_OSP_WAIT, GPSW_COMM_TASK);
        call GPSTimer.startOneShot(DT_GPS_OSP_WAIT_TIME);	// wait for the switch to go.
        return;

      case GPSC_CONFIG:
        /*
         * When we get to the CONFIG state, the gps i/o pipes should be empty.
         * If not empty (idle), flag the unexpected condition and drain any
         * packets that may be in the pipe.
         *
         * First, make sure we can talk to the GPS chip by requesting
         * the SW Ver.
         */
        gps_send_block(osp_idle_block, BUF_INCOMING_SIZE);
        if (!checkIdle()) {
          gps_panic_warn(8, gpsc_state);
          gpsc_change_state(GPSC_CONFIG_B, GPSW_COMM_TASK);
          post gps_comm_task();
          return;
        }
        g_t0 = call LocalTime.get();
	gps_send_block(osp_send_sw_ver, sizeof(osp_send_sw_ver));

      case GPSC_CONFIG_A:
        /*
         * process any bytes that may have come back from sending sw_ver
         * request.  Give it upto 200ms for the sw_ver to come back.
         */
        if (process_incoming()) {
          gpsc_change_state(GPSC_CONFIG_A, GPSW_COMM_TASK);
          return;
        }
	gpsc_change_state(GPSC_SW_VER, GPSW_TIMER);
	call GPSTimer.startPeriodic(10);
        gpsc_limit = 1000;
        return;

      case GPSC_CONFIG_B:
        /*
         * error state, clean out pending incoming bytes.  Then try
         * again.  From the top.
         */
        if (process_incoming()) {
          /*
           * more packets need to be handled, stay in this state
           * when done processing the packets we will come back here
          */
          return;
        }
        gps_send_block(osp_idle_block, BUF_INCOMING_SIZE);
        if (checkIdle()) {
          gpsc_change_state(GPSC_CONFIG_A, GPSW_COMM_TASK);
          gps_send_block(osp_send_sw_ver, sizeof(osp_send_sw_ver));
        }
        post gps_comm_task();
        return;

        /*
         * looking for the sw_ver response.
         */
      case GPSC_SW_VER:                 /* traced */
      case GPSC_SW_VER_A:               /* not traced */
        gps_send_block(osp_idle_block, BUF_INCOMING_SIZE);
        if (checkIdle()) {
          /* idle, wait some more, Periodic will catch us */
          gpsc_change_state(GPSC_SW_VER_A, GPSW_COMM_TASK);
          return;                       /* let the timer do it */
        }

        /* fall through to handle I/O */

      case GPSC_SW_VER_B:
        nop();
        do {
          /*
           * We are looking for the sw_ver ack.  This causes a state change
           * to SW_VER_FINI.  Depending on what is going on, we can be in
           * any of the SW_VER states.
           */
          blocked = process_incoming();
          if (gpsc_state == GPSC_SW_VER_FINI)
            break;
          if (blocked) {
            gpsc_change_state(GPSC_SW_VER_B, GPSW_COMM_TASK);
            return;
          }
          gpsc_change_state(GPSC_SW_VER_A, GPSW_COMM_TASK);
          post gps_comm_task();         /* grab more data */
          return;
        } while (0);
        call GPSTimer.stop();
	gps_mark(0xe0);

        /*
         * got the SW_VER_FINI, but we may have some left over bytes that still
         * need to be processed.
         */

      case GPSC_SW_VER_FINI_A:
        if (process_incoming()) {
          gpsc_change_state(GPSC_SW_VER_FINI_A, GPSW_COMM_TASK);
          post gps_comm_task();
          return;
        }
        nop();
        if (gpsc_operational) {
          gpsc_change_state(GPSC_POLL_NAV, GPSW_COMM_TASK);
          post gps_comm_task();
          return;
        }
        gps_send_block(osp_idle_block, BUF_INCOMING_SIZE);

      case GPSC_CONFIG_C:
        if (process_incoming()) {
          gpsc_change_state(GPSC_CONFIG_C, GPSW_COMM_TASK);
          return;
        }

//	gps_send_block(osp_message_rate_msg, sizeof(osp_message_rate_msg));
//      process_incoming();

        gpsc_change_state(GPSC_POLL_NAV, GPSW_COMM_TASK);
        post gps_comm_task();
        return;

      case GPSC_POLL_NAV:
	gps_mark(0xe1);
	gps_send_block(osp_poll_clock, sizeof(osp_poll_clock));

      case GPSC_POLL_NAV_A:
        if (process_incoming()) {
          gpsc_change_state(GPSC_POLL_NAV_A, GPSW_COMM_TASK);
          return;
        }

	gps_send_block(osp_poll_nav, sizeof(osp_poll_nav));

      case GPSC_POLL_NAV_B:
        if (process_incoming()) {
          gpsc_change_state(GPSC_POLL_NAV_B, GPSW_COMM_TASK);
          return;
        }

	gps_send_block(osp_enable_tracker, sizeof(osp_enable_tracker));

      case GPSC_POLL_NAV_C:
        if (process_incoming()) {
          gpsc_change_state(GPSC_POLL_NAV_C, GPSW_COMM_TASK);
          return;
        }
        gpsc_change_state(GPSC_ON, GPSW_COMM_TASK);
        gpsc_operational = TRUE;
        gps_cmd = GPS_CMD_NONE;
        signal GPSControl.startDone(SUCCESS);
	call GPSTimer.startPeriodic(10);
        nop();
	return;

      case GPSC_ON:
      case GPSC_ON_A:
        gps_send_block(osp_idle_block, BUF_INCOMING_SIZE);
        if (checkIdle())
          return;                       /* wait for timer, if empty */

      case GPSC_ON_B:
        nop();
        if (process_incoming()) {
          gpsc_change_state(GPSC_ON_B, GPSW_COMM_TASK);
          return;
        }
        gpsc_change_state(GPSC_ON_A, GPSW_COMM_TASK);
        post gps_comm_task();
        return;

      case GPSC_SHUTDOWN_CLEAN:
        call GPSTimer.stop();

      case GPSC_SHUTDOWN_CLEAN_A:
        gps_send_block(osp_idle_block, BUF_INCOMING_SIZE);
        if (checkIdle()) {
          gpsc_change_state(GPSC_PULSE_OFF, GPSW_COMM_TASK);
          call HW.gps_set_on_off();
          call GPSTimer.startOneShot(DT_GPS_ON_OFF_PULSE_WIDTH);
          return;
        }

      case GPSC_SHUTDOWN_CLEAN_B:
        if (process_incoming()) {
          gpsc_change_state(GPSC_SHUTDOWN_CLEAN_B, GPSW_COMM_TASK);
          return;
        }
        gpsc_change_state(GPSC_SHUTDOWN_CLEAN_A, GPSW_COMM_TASK);
        post gps_comm_task();
        return;

      /* striping while waiting */
      case GPSC_PULSE_OFF_WAIT:
      case GPSC_PULSE_OFF_WAIT_A:
        gps_send_block(osp_idle_block, BUF_INCOMING_SIZE);
        if (checkIdle())
          return;                       /* timer, wait for more to strip */

      case GPSC_PULSE_OFF_WAIT_B:
        if (process_incoming()) {
          gpsc_change_state(GPSC_PULSE_OFF_WAIT_B, GPSW_COMM_TASK);
          return;
        }
        gpsc_change_state(GPSC_PULSE_OFF_WAIT_A, GPSW_COMM_TASK);
        post gps_comm_task();
        return;

      /* send shutdown msg, then wait and strip */
      case GPSC_SHUTDOWN_MSG:
	gps_mark(0xf0);
        gps_send_block(osp_shutdown, sizeof(osp_shutdown));

      case GPSC_SHUTDOWN_MSG_A:
        if (process_incoming()) {
          gpsc_change_state(GPSC_SHUTDOWN_MSG_A, GPSW_COMM_TASK);
          return;
        }
        gpsc_limit = 20;
        call GPSTimer.startPeriodic(10);
        gpsc_change_state(GPSC_SHUTDOWN_MSG_WAIT, GPSW_COMM_TASK);
        return;                         /* wait for timer */

      /* strip messages while waiting */
      case GPSC_SHUTDOWN_MSG_WAIT:
      case GPSC_SHUTDOWN_MSG_WAIT_A:
        gps_send_block(osp_idle_block, BUF_INCOMING_SIZE);
        if (checkIdle())
          return;                       /* wait for timer, if empty */

      case GPSC_SHUTDOWN_MSG_WAIT_B:
        if (process_incoming()) {
          gpsc_change_state(GPSC_SHUTDOWN_MSG_WAIT_B, GPSW_COMM_TASK);
          return;
        }
        /* go get more message bytes */
        gpsc_change_state(GPSC_SHUTDOWN_MSG_WAIT_A, GPSW_COMM_TASK);
        post gps_comm_task();
        return;

#ifdef notdef
      case GPSC_FINISH:
	gpsc_operational = 1;
	gpsc_boot_time = call LocalTime.get() - t_gps_pwr_on;
//	call LogEvent.logEvent(DT_EVENT_GPS_BOOT_TIME, (uint16_t) gpsc_boot_time);
	return;
#endif

    }
  }


  /*
   * Init gets called on the way up, so we know we are rebooting the machine.
   */
  command error_t Init.init() {
    /* gpsc_state is set to GPSC_OFF (0) by ram initializer */
    call HW.gps_spi_init();
    return SUCCESS;
  }


#ifdef notdef
 event void Boot.booted() {
    /*
     * First make sure the gps is down.  When booting make sure to power cycle
     * assumes init then booted.
     *
     * We set operational to 0 which changes the behaviour of the state machine
     * so it does somewhat different things on the way up.  Including sending
     * some packets to see the s/w version etc.  This will also causes the boot
     * signal to occur when the gps comes all the way up.
     */

//    call LogEvent.logEvent(DT_EVENT_GPS_BOOT,0);
    call HW.gps_off();
    gpsc_change_state(GPSC_OFF, GPSW_NONE);
    gpsc_operational = FALSE;
    call GPSControl.start();
  }
#endif


  void gps_pulse_on(gps_where_t w) {
    nop();
    call GPSMsgControl.start();
    gpsc_change_state(GPSC_PULSE_ON, w);
    call GPSTimer.startOneShot(DT_GPS_ON_OFF_PULSE_WIDTH);
    t_gps_pwr_on = call LocalTime.get();
    t_gps_pwr_on_usecs = call Platform.usecsRaw();
    call HW.gps_set_on_off();

//    call LogEvent.logEvent(DT_EVENT_GPS_START, 0);
  }


  /*
   * Start GPS.
   *
   * This is what is normally used to fire the GPS up for readings.
   * Assumes the gps has its comm settings properly setup.  SirfBin-SPI
   *
   * This is the low level state machine.  It expects to power up the gps
   * and for it to behave in a reasonable manner as observed during prototyping.
   *
   * Some thoughts...
   *
   * 1) pwr is assumed to always be on.   This initial start up condition may have
   *    to be modified for initial turn on (power coming up).   Some form of power up
   *    time out or delay (could be up to 5 secs.)   May want to do that iff initial
   *    turn on fails.
   *
   * 2) We may also want to delay getting messages from the GPS until it has had time
   *    to recapture.  (Probably not an issue.   This was an issue for the sirf3 chip
   *    because it was interrupt driven char i/o.   We are SPI running at 4 Mbps).
   *
   * 3) can we immediately throw commands requesting the navigation data we want?
   *
   * 4) can we send commands back to back?
   *
   * 5) is it reliable?
   *
   * 6) would it be better to sequence?
   *
   * Dedicated h/w.  SPI initialized via call to HW.gps_spi_init() provided by platform
   * gps h/w code.  See Gsd4eInterface.nc
   */

  command error_t GPSControl.start() {
    if (gpsc_state != GPSC_OFF) {
      gps_panic_warn(9, gpsc_state);
      return SUCCESS;
    }
    nop();

    if (gps_cmd != GPS_CMD_NONE) {       /* check for something else going on */
      gps_panic_warn(99, gps_cmd);
      return EBUSY;
    }

    gps_cmd = GPS_CMD_TURNON;           /* we want to end up operational */
    if (call HW.gps_awake()) {
      /*
       * OFF but Awake.  Shouldn't be here.  Go through a full reset cycle
       * but first do a panic_warn to flag it.
       *
       * We do a full reset cycle to make sure we can bring it up.  For example
       * it is possible that the gps is awake but in nmea mode.  In which case
       * we won't be able to talk correctly to it.
       */
      gps_panic_warn(10, call HW.gps_awake());
      gpsc_operational = FALSE;
      gpsc_change_state(GPSC_RESET_PULSE, GPSW_START);
      call GPSTimer.startOneShot(DT_GPS_RESET_PULSE_WIDTH);
      call HW.gps_set_reset();
      return SUCCESS;
    }
    
    /*
     * not awake (which is what we expected).   So kick the on_off pulse
     * and wake the critter up.
     */
    gps_pulse_on(GPSW_START);
    return SUCCESS;
  }


  /*
   * Stop.
   *
   * Stop all GPS activity.
   */
  command error_t GPSControl.stop() {
    if (gpsc_state == GPSC_OFF) {
      gps_panic_warn(99, gpsc_state);
      return EOFF;
    }
    if (gps_cmd != GPS_CMD_NONE)
      return EBUSY;
    if (!call HW.gps_awake()) {
      gps_panic_warn(11, call HW.gps_awake());
      gpsc_change_state(GPSC_OFF, GPSW_STOP);
      return EOFF;
    }
    gps_mark(0xb0);
    gps_cmd = GPS_CMD_TURNOFF;

    /*
     * fire up a timeout, to protect against a chatty gps.
     * if we timeout, we will panic out of GPSTimer.fired
     * in one of the SHUTDOWN_CLEAN states.
     */
    gpsc_change_state(GPSC_SHUTDOWN_CLEAN, GPSW_STOP);
    call GPSTimer.startOneShot(DT_GPS_SHUTDOWN_CLEAN_TO);
    post gps_comm_task();
    return SUCCESS;
  }


  /*
   * the GPSMsg processor can take some time to process the current packet.
   * while it is doing so we shouldn't feed any more data to it.
   * When it has finished with the current packet and the buffer becomes
   * free again, it will signal us to resume.
   */
  event void GPSMsgS.resume() {
    post gps_comm_task();
  }


  /*
   * packetAvail
   *
   * input:     msg     pointer to packet, points at beginning of SIRF packet
   *            len     full length of the SIRF packet.  (len in the SIRF
   *                    only includes payload,  we pass in the full length of
   *                    the packet).
   * output:    bool    TRUE if packet has been consummed.
   *                    FALSE if the Msg Processor should continue processing.
   *
   * when the GPSMsg processor has put together a full packet from the GPS
   * it will signal with a pointer to the packet.  If we handle it at the
   * low level, we will return TRUE to indicate that we have consumed it.
   */
  event bool GPSMsgS.packetAvail(uint8_t *msg, uint16_t len) {
    osp_header_t *oh;
    osp_ack_nack_t *an;
    gps_soft_version_data_nt *gsv;
    register uint16_t l;

    oh  = (void *) msg;
    gsv = (void *) msg;
    an  = (void *) msg;
    nop();
    nop();
    switch (oh->mid) {
      default:
        break;

      case MID_OK_TO_SEND:
        return TRUE;

      case MID_SW_VERSION:
        u_t[3] = call Platform.usecsRaw();
        g_t1 = call LocalTime.get();
        /*
         * should only show up if we've asked for it.  Just copy over the
         * payload.  Copy over just data bytes, don't include the MID
         */
        l = len - SIRF_OVERHEAD - 1;
        if (l > 80) l = 80;
        memcpy(gps_version, gsv->data, l);
        return TRUE;

      case MID_SSB_ACK:
        switch (an->ack_id) {
          case MID_SEND_SW_VER:
            if (gpsc_state < GPSC_SW_VER &&
                gpsc_state > GPSC_SW_VER_C)
              gps_panic(99, gpsc_state);
            gpsc_change_state(GPSC_SW_VER_FINI, GPSW_MSG_BOUNDARY);
            return TRUE;

          case MID_POLL_CLOCK:
          case MID_POLL_NAV:
          case MID_SET_MSG_RATE:
            return TRUE;
        }
        gps_panic(98, an->mid);
        return TRUE;

      case MID_SSB_ERROR:
      case MID_SSB_NACK:
        gps_panic(99, gpsc_state);
        return TRUE;
    }
    nop();
    return TRUE;
  }


  event void GPSTimer.fired() {
    switch (gpsc_state) {
      default:
      case GPSC_FAIL:
      case GPSC_OFF:
	gps_panic(12, gpsc_state);      /* no timer should be running */
	return;

      case GPSC_RESET_PULSE:
	call HW.gps_clr_reset();
	gpsc_change_state(GPSC_RESET_WAIT, GPSW_TIMER);
	call GPSTimer.startOneShot(DT_GPS_RESET_WAIT_TIME);
	return;

      case GPSC_RESET_WAIT:
	if (call HW.gps_awake()) {
          gps_panic(112, gpsc_state);
	  gpsc_change_state(GPSC_FAIL, GPSW_TIMER);
	  return;
        }
        switch (gps_cmd) {
          default:
            gps_panic(113, gpsc_state);
            gpsc_change_state(GPSC_FAIL, GPSW_TIMER);
            return;

          case GPS_CMD_TURNON:
            gps_pulse_on(GPSW_TIMER);
            return;

          case GPS_CMD_TURNOFF:
            driver_stop(GPSW_TIMER);
            return;
        }

      case GPSC_PULSE_ON:
	call HW.gps_clr_on_off();
	if (!call HW.gps_awake()) {
	  gps_panic(13, gpsc_state);
	  gpsc_change_state(GPSC_FAIL, GPSW_TIMER);
	  return;
	}
        gpsc_change_state(GPSC_FIRST, GPSW_TIMER);
        post gps_comm_task();
        return;

      case GPSC_OSP_WAIT:
	gpsc_change_state(GPSC_CONFIG, GPSW_TIMER);
        post gps_comm_task();
	return;

      case GPSC_SW_VER:
      case GPSC_SW_VER_A:
      case GPSC_SW_VER_B:
        if (--gpsc_limit == 0) {
          gps_panic_warn(88, gpsc_state);
        }
        post gps_comm_task();
        return;

      case GPSC_ON:
      case GPSC_ON_A:
      case GPSC_ON_B:
        post gps_comm_task();
        return;

      case GPSC_PULSE_OFF:
	call HW.gps_clr_on_off();
	gpsc_change_state(GPSC_PULSE_OFF_WAIT, GPSW_TIMER);
        gpsc_limit = 100;
	call GPSTimer.startPeriodic(10);
	return;

      case GPSC_PULSE_OFF_WAIT:
      case GPSC_PULSE_OFF_WAIT_A:
      case GPSC_PULSE_OFF_WAIT_B:
	if (!call HW.gps_awake()) {
          driver_stop(GPSW_TIMER);
	  return;
	}
        if (--gpsc_limit == 0) {
          call GPSTimer.stop();
	  gpsc_change_state(GPSC_SHUTDOWN_MSG, GPSW_TIMER);
        }
        post gps_comm_task();
        return;

      case GPSC_SHUTDOWN_MSG_WAIT:
      case GPSC_SHUTDOWN_MSG_WAIT_A:
	if (!call HW.gps_awake()) {
          driver_stop(GPSW_COMM_TASK);
	  return;
	}
        if (--gpsc_limit == 0) {
          /* gps_cmd should be GPS_CMD_TURNOFF so reset does the right thing */
          gps_panic_warn(14, gpsc_state);
          gpsc_change_state(GPSC_RESET_PULSE, GPSW_START);
          call GPSTimer.startOneShot(DT_GPS_RESET_PULSE_WIDTH);
          call HW.gps_set_reset();
          return;
        }
        post gps_comm_task();           /* strip any messages */
        return;
    }
  }

  async event void Panic.hook() { }
}
