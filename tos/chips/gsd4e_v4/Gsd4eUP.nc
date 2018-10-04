/*
 * Copyright (c) 2008-2010 Eric B. Decker
 * Copyright (c) 2017-2018 Eric B. Decker, Daniel J. Maltbie
 * All rights reserved.
 *
 * This program is free software: you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation, either version 3 of the License, or
 * any later version.
 *
 * This program is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU General Public License for more details.
 *
 * You should have received a copy of the GNU General Public License
 * along with this program.  If not, see <https://www.gnu.org/licenses/>.
 * See COPYING in the top level directory of this source tree.
 *
 * Contact: Eric B. Decker <cire831@gmail.com>
 *          Daniel J. Maltbie <dmaltbie@daloma.org>
 *
 * Dedicated usci uart port.
 * refactored 1/26/2017 for mm6a, dev6a, port abstraction
 * originally based on UART sirf3 driver.  rewritten for
 * SirfStarIV using UART and Port abstraction.
 */

#include <panic.h>
#include <platform_panic.h>
#include <gps.h>
#include <sirf_driver.h>
#include <typed_data.h>
#include <overwatch.h>

#ifndef PANIC_GPS
enum {
  __pcode_gps = unique(UQ_PANIC_SUBSYS)
};

#define PANIC_GPS __pcode_gps
#endif

/*
 * *** GPS Power Up Notes:
 *
 * The Gsd4e chips are a bit strange.  They have this ON_OFF toggle that
 * kicks the chip into different modes.  But first let's talk about powering
 * the chip up.  This will occur when the whole system turns on or if power
 * to the GPS has been yanked.
 *
 * Much of the documentation we use can be obtained from
 * [1] https://www.origingps.com/wp-content/uploads/2016/07/
 *             ORG4472-Datasheet-C02-1.pdf
 *
 * The ORG4472 is another GSD4e chip that we used earlier in the
 * development process.  The Antenova M10478 is what we are using now and
 * is another GSD4e based gps chip.  It seems to be essentially the same as
 * the ORG4472.  The M10478 documentation sucks so doesn't take much for
 * the ORG documentation to be better.
 *
 * After power is applied, the gps chip needs to let power stabilize and
 * then will start up its RTC.  See page 27 of [1].  When things are good
 * it will assert AWAKE for 300us.  This is the initial AWAKE (aka WAKEUP)
 * pulse (AWAKE_0).  Only after AWAKE_0, are we allowed to try to talk to
 * the chip.  Prior to this, the chip will ignore us.
 *
 * So we want at a minimum deltaT0 (power stabilization, ~300ms) + deltaT6
 * the pulse width of AWAKE_0 (~300ms).  see table 9-1, page 28.  But there
 * appears to be some unaccounted time between the end of deltaT0 and the
 * rising edge of AWAKE_0.  So this will have to be observed.
 *
 * Note, many platforms have a 32Ki XTAL that needs to be brought up.  This
 * can take considerable time and this can be a good area for overlap with
 * the GPS power on.  However, our state machine won't be running yet, so
 * it is unclear how to capture this.
 *
 * Another technique involves using an interrupt to capture the rising edge
 * of AWAKE_0.  Instead, We simply set PWR_UP_DELAY to be 1024.  This isn't
 * as big of a deal as it seems.  We typically sit in HIBERNATE and toggle
 * between ON and HIBERNATE.  The 1024ms delay hits when we come out of
 * power off.  Once the chip is past POR we won't see the 1024ms delay.
 *
 * Once we are allowed to toggle ON_OFF following power on, there is
 * another big window during which the ARM7 onboard the GPS is starting up.
 * This is the WAKE_UP_DELAY.  This is the time from the initial ON_OFF
 * toggle to when the ARM7 has booted.  After the ARM7 has booted we can
 * reasonably expect the chip to respond to input messages.
 *
 * Once the ARM7 comes up it will output an OK-TO-SEND msg,
 * A0A2 0002 1201 0013 B0B3.  This message can be used to terminate any
 * pending WAKE_UP_DELAY.  This of course only works if the gps and
 * its port are configured properly.
 *
 *
 * *** Startup communications.
 *
 * Anytime the GPS transitions out of OFF we first want to make sure that
 * we can communicate with the chip.  This could be done when we first boot
 * and then we could assume that the GPS can still communicate but the
 * overhead of verifing communications isn't that bad.
 *
 * After a reboot, a GPSControl.turnOn() will first look at awake.  If awake
 * we probe and see if we can talk.  This bypasses the initial power on/on_off
 * toggle.  If we are awake and toggle on/off, depending on the mode the GPS is
 * in, it will go to sleep.  So the state machine handles this.
 *
 * SirfBin is abbreviated SB, NMEA as NM.  When changing the comm configuration,
 * we use "Set Binary Serial Port" (MID134, 0x86) and for NMEA we use "Set
 * Serial Port" ($PSRF100).
 *
 * The target comm configuration we want is SB-<target>, where target is the
 * operational baud rate, 115200 initially but could be higher if we need
 * the performance.
 *
 * When we transition out of OFF, we power up (wait), wiggle ON/OFF to turn
 * the gps on (wait), set <target> baud and listen.  If everything is
 * configured properly (typical case), we should get an OK-TO-SEND (OTS).
 * This will transition us to a working state without reconfiguring the GPS.
 * or the UART h/w we are using.
 *
 * If this first listen (PROBE_0) times out, then we have to try various
 * configurations.  This occurs via PROBE_CYCLE through CHK_RX_WAIT.  After
 * sending a reconfigure command (and setting the appropriate baud rate),
 * we force a response from the GPS using a PEEK command.  We basically
 * tell the GPS ARM to send us the 4 bytes at address 0 (the restart
 * vector?).  This is the lowest overhead mechanism to force a response
 * from the GPS.
 *
 * *** State Machine Description
 *
 * FAIL             gps has failed.
 * OFF              gps power is off?  Or we rebooted.
 *
 * PWR_UP_WAIT:     delay waiting for initial power on window
 *
 * PROBE_0:         wakeup wait, wait for a potential OTS (ok-to-send).
 *                  Receiving OTS will cause a MsgStart which transitions
 *                  the state machine.  If we timeout send a Probe (peek)
 *                  in case we missed the OTS for some reason.
 *
 * PROBE_CYCLE:     start a new probe cycle, send the next configuration
 *                  we want to try.  If we've run out, signal gps_boot_fail
 *                  and quit.
 *
 * PROBE_x1:        psuedo state, if we haven't run out of configs to try.
 *                  actually sets the new speed and sends the config.
 *
 * CHK_TX_WAIT:     We are actively transmitting (via tx interrtups) the
 *                  current configuration.  The tx_timer is a deadman and
 *                  shouldn't go off.  Proper termination is via
 *                  HW.gps_send_block_done.
 *
 * CHK_TA_WAIT:     After the config change message is sent we delay a turn
 *                  around time to give the gps time to actually change its
 *                  configuration.
 *
 * CHK_TX1_WAIT:    We want to force a response from the gps to see if
 *                  the configuration worked.  TX1_WAIT is active while
 *                  we are sending this probe (peek).  tx_timer should not
 *                  expire (deadman for transmit).
 *
 * CHK_RX_WAIT:     Waiting to receive the response from the probe.  If
 *                  rx_timer expires we assume the probe didn't work and
 *                  we cycle to a different configuration.  If the probe
 *                  times out back to PROBE_CYCLE to try the next
 *                  configuration.
 *
 * CHK_MSG_WAIT:    msgStart from the protocol engine will transition us
 *                  into MSG_WAIT where we are waiting for the message
 *                  to finish being received.
 *
 *                  If we time out waiting for Proto.msgEnd, we will try
 *                  <N> times (chk_trys) to elicit a response by cycling
 *                  back to CHK_TA_WAIT.
 *
 *                  If we have already tried too many times, we will cycle
 *                  PROBE_CYCLE to try a different comm configuration.
 *
 * When the first msg has been received, we will transition out of CHK_MSG_WAIT
 * to ON and signal gps_booted.  If the boot fails, we haven't been able to
 * establish communication, and we signal gps_boot_fail (from PROBE_CYCLE).
 *
 *
 * HIBERNATE        sleeping but configured.
 *
 * ON:              After the proper configuration is established, we
 *                  finish in ON.  At Msg boundary.
 *
 * ON_RX            In the process of receiving a message, intramessage.
 *
 * ON_TX            In the process of sending a message.  TX deadman timer
 *                  is running.
 *
 * ON_RX_TX         Both receiving and sending.
 *
 *
 * *** TimeOut Values
 *
 * In varous places we fire up timers to make sure we don't hang.  We use
 * various timeout deadman or rx window values to set these timers.  These
 * values are computed based on what baud rate we are running and how long
 * the message is.
 *
 * We express these timeout values in terms of the target baud.  For example
 * when we are using messages out of the probe_table, there is a to_mod,
 * (time out modifier) associated with each entry.
 *
 * The formula for a calulated transit time (in msecs) is:
 *
 *    T_t = (len * byte_time * to_mod + 500000)/1000000
 *
 * len is length in bytes, byte_time is a single byte transit time in nano
 * secs at the target baud rate, and to_mod is the ratio of target/actual,
 * ie.  115200/4800 = ~24 for 4800 baud.  Assuming target baud is 115200.
 *
 * The calculated transit time for a 28 byte message at 4800 baud (to_mod 24),
 * with a target byte time (115200) of 86805, would be:
 *
 *    T_t = (28 * 86805 * 24 + 500000) / 1000000 = 58ms
 *
 * we generally use a timeout that is 4 times the transit time...
 *
 *    T_to = ((len * byte_time * to_mod * 4) + 500000) / 1000000
 *
 * in the above example we get 233ms.
 *
 * A further wrinkle is we might actually be using binary time in which
 * case the equation becomes...
 *
 *    T_to = (((len * byte_time * to_mod * 4) + 500000) / 1000000) * (1024 / 1000)
 *
 * Rather than complicate the actual computation, we simply modify
 * the byte_time.  If byte_time is specified in binary time that will also be
 * the units of the result.
 */

typedef enum {
  GPSC_OFF  = 0,                        /* pwr is off */
  GPSC_FAIL = 1,
  GPSC_RESET_WAIT,                      /* reset dwell */

  GPSC_PWR_UP_WAIT,                     /* power up delay */
  GPSC_PROBE_0,
  GPSC_PROBE_CYCLE,

  /* PROBE_x1 is a pseudo state.  PROBE_CYCLE always drops
   * immediately into it.  never actually gets set
   */
  GPSC_PROBE_x1,                        // place holder

  GPSC_CHK_TX_WAIT,
  GPSC_CHK_TA_WAIT,                     /* turn around, changing comm */
  GPSC_CHK_TX1_WAIT,
  GPSC_CHK_RX_WAIT,
  GPSC_CHK_MSG_WAIT,

  GPSC_CONFIG,                          // place holder
  GPSC_CONFIG_WAIT,                     // place holder

  GPSC_HIBERNATE,                       // place holder

  GPSC_ON,                              // at msg boundary
  GPSC_ON_RX,                           // in receive
                                        // RX_TX and TX MUST follow ON_RX
  GPSC_ON_RX_TX,                        // transmitting and receiving
  GPSC_ON_TX,                           // in middle of transmitting
} gpsc_state_t;                         // gps control state


typedef enum {
  GPSW_NONE = 0,
  GPSW_TURNON,
  GPSW_TURNOFF,
  GPSW_STANDBY,
  GPSW_SEND_BLOCK_TASK,
  GPSW_PROBE_TASK,
  GPSW_PWR_TASK,
  GPSW_TX_TIMER,
  GPSW_RX_TIMER,
  GPSW_PROTO_START,
  GPSW_PROTO_ABORT,
  GPSW_PROTO_END,
  GPSW_TX_SEND,
} gps_where_t;


typedef enum {
  GPSE_NONE = 0,
  GPSE_STATE,                           /* state change */
  GPSE_ABORT,                           /* protocol abort */
  GPSE_SPEED,                           /* speed change */
  GPSE_TX_POST,                         /* tx h/w int posted */
  GPSE_TX_TIMEOUT,                      /* tx timeout */
} gps_event_t;


norace uint32_t send_block_done_usecs;

/*
 * gpsc_state: current state of the driver state machine
 */
norace gpsc_state_t	    gpsc_state;

/* instrumentation */
uint32_t		    gpsc_boot_time;		// time it took to boot.
uint32_t		    gpsc_cycle_time;		// time last cycle took
uint32_t		    gpsc_max_cycle;		// longest cycle time.
norace uint32_t		    t_gps_first_char;

#ifdef GPS_LOG_EVENTS

norace uint16_t g_idx;                  /* index into gbuf */

#ifdef GPS_EAVESDROP
#define GPS_EAVES_SIZE 512

norace uint8_t  gbuf[GPS_EAVES_SIZE];
#endif

typedef struct {
  uint32_t     ts;                      /* Tmilli */
  uint32_t     us;                      /* raw usecs, Tmicro */
  gps_event_t  ev;
  gpsc_state_t gc_state;
  uint32_t     arg;
  uint16_t     g_idx;
} gps_ev_t;

#define GPS_MAX_EVENTS 32

gps_ev_t g_evs[GPS_MAX_EVENTS];
uint8_t g_nev;			// next gps event

#endif   // GPS_LOG_EVENTS

/*
 * gps_probe_table
 *
 * The probe_table holds various comm configuration messages.
 *
 * Initially we assume the GPS is at SB-<target>.  After reset or power on,
 * we set the UART h/w to <target> and wait for WAKE_UP_DELAY to see the
 * Ok_To_Send (OTS).  If seen the state machine cycles and we eventually
 * transition to ON.
 *
 * If we expire the WAKE_UP_DELAY then we throw a probe (peek_0) at the
 * gps to force a response.  This corresponds to probe_index -1.
 *
 * But if that doesn't work we go to probe_index 0 and start with
 * the first entry in the table to see if we can find a configuration
 * that works.
 *
 * The 1st entry in the table should be the one that is most likely
 * to work.
 *
 * Entries in the probe_table are configurations that might correspond to
 * how the gps chip is configured.  After each configuration is sent we
 * reconfigure the h/w to our <target> and send a probe (peek_0) to elicit
 * a response.
 *
 * If we run through the entire probe_table without success, we reset
 * the GPS and try again.  If that fails we give up.
 *
 * When we have found a configuration that works, as our last bit will
 * send a SB-sw_ver.  We want to log the SW version of the chip
 * for record keeping.
 */

#define GPT_MAX_INDEX 4

const gps_probe_entry_t gps_probe_table[GPT_MAX_INDEX] = {
/*   rate mod             len                msg   */
#if GPS_TARGET_SPEED == 115200
  {  4800, 24, sizeof(nmea_sirf_115200), nmea_sirf_115200 },
  {  9600, 12, sizeof(nmea_sirf_115200), nmea_sirf_115200 },
  {  4800, 24, sizeof(sirf_115200),      sirf_115200      },
  {  9600, 12, sizeof(sirf_115200),      sirf_115200      },
#elif GPS_TARGET_SPEED == 9600
  {  4800, 2, sizeof(nmea_sirf_9600), nmea_sirf_9600 },
  {  9600, 1, sizeof(nmea_sirf_9600), nmea_sirf_9600 },
  {  4800, 2, sizeof(sirf_9600),      sirf_9600      },
  {  9600, 1, sizeof(sirf_9600),      sirf_9600      },
#else
#error GPS_TARGET_SPEED neither 115200 nor 9600
#endif
};

       int32_t  gps_probe_index;        // keeps track of which table entry to use
norace uint32_t gps_chk_trys;           // remaining chk_msgs to try  CHK_MSG_WAIT


module Gsd4eUP {
  provides {
    interface GPSControl;
    interface GPSTransmit;
  }
  uses {
    interface Gsd4eUHardware as HW;
    interface PwrReg as GPSPwr;         /* gps power sw  */

    /*
     * This module uses two timers, GPSTxTimer and GPSRxTimer.
     *
     * GPSTxTimer primarily transmit deadman timing.  Also used
     *            for various state machine functions.
     * GPSRxTimer receive deadman timing.
     */
    interface Timer<TMilli> as GPSTxTimer;
    interface Timer<TMilli> as GPSRxTimer;
    interface Timer<TMilli> as GPSRxErrorTimer;
    interface LocalTime<TMilli>;

    interface GPSProto as SirfProto;

    interface Panic;
    interface Platform;
    interface Collect;
    interface CollectEvent;
    interface OverWatch;
//  interface Trace;
  }
}
implementation {

  uint32_t t_gps_pwr_on;         // when driver started

  /*
   * req_rx_len:        requested rx len (for timeout)
   * cur_rx_len:        current   rx len (for timeout)
   *
   * The interrupt level can change state and can request that the RxTimer
   * be modified.  When this is needed, the interrupt level will fill in
   * req_rx_len and post timer_task.  cur_rx_len indicates what we were
   * last set to.
   *
   * To kill the rx_timer, set req_rx_len to 0 and post timer_task.
   */
  norace int16_t m_req_rx_len;          // requested rx len (for timeout)
         int16_t m_cur_rx_len;          // cur       rx len (for timeout)

  norace uint32_t m_rx_errors;          // rx errors from the h/w
  norace uint32_t m_last_rpt_rx_errors; // last we reported.
  norace uint16_t m_first_rx_error;     // first rx_stat we saw
  norace uint32_t m_last_rx_collection; // ms time of last_rx error collection
         uint32_t m_lost_tx_ints;       // on_tx, time outs
         uint32_t m_lost_tx_retries;
         uint32_t m_tx_time_out;        // last tx timeout ued

#define GPS_MAX_LOST_TX_RETRIES 5

  void gps_warn(uint8_t where, parg_t p, parg_t p1) {
    call Panic.warn(PANIC_GPS, where, p, p1, 0, 0);
  }

  void gps_panic(uint8_t where, parg_t p, parg_t p1) {
    call Panic.panic(PANIC_GPS, where, p, p1, 0, 0);
  }


  /* collect_gps_pak
   *
   * add a gps packet to the data stream.  Debugging etc.
   */
  static void collect_gps_pak(uint8_t *pak, uint16_t len, uint8_t dir) {
    dt_gps_t hdr;

    if (call OverWatch.getLoggingFlag(OW_LOG_RAW_GPS)) {
      hdr.len      = sizeof(hdr) + len;
      hdr.dtype    = DT_GPS_RAW_SIRFBIN;
      hdr.mark_us  = 0;
      hdr.chip_id  = CHIP_GPS_GSD4E;
      hdr.dir      = dir;

      /* time stamp added by Collect */
      call Collect.collect((void *) &hdr, sizeof(hdr), pak, len);
    }
  }


  /* gps log event */
  void gpsc_log_event(gps_event_t ev, uint32_t arg) {
#ifdef GPS_LOG_EVENTS
    uint8_t idx;

    atomic {
      idx = g_nev++;
      if (g_nev >= GPS_MAX_EVENTS)
	g_nev = 0;
      g_evs[idx].ts = call LocalTime.get();
      g_evs[idx].us = call Platform.usecsRaw();
      g_evs[idx].ev = ev;
      g_evs[idx].gc_state = gpsc_state;
      g_evs[idx].arg = arg;
      g_evs[idx].g_idx = g_idx;
    }
#endif
  }


  /*
   * ORG docs says ON_OFF must be > 62us but they recommend 100ms which
   * seems kind of long.  If 105us doesn't work, well we will have to
   * rethink this.
   */
  void toggle_gps_on_off() {
    uint32_t t0;

    call HW.gps_set_on_off();
    t0 = call Platform.usecsRaw();
    while (call Platform.usecsRaw() - t0 < 105) ;
    call HW.gps_clr_on_off();
  }


  void gps_wakeup() {
    uint32_t t0;

    if (!call HW.gps_awake()) {
      toggle_gps_on_off();
      t0 = call Platform.usecsRaw();
      while (call Platform.usecsRaw() - t0 < 105) {
        if (call HW.gps_awake()) return;
      }
      gps_panic(8, 0, 0);
    }
  }


  void gps_reset() {
    uint32_t t0;

    call HW.gps_set_reset();
    t0 = call Platform.usecsRaw();
    while (call Platform.usecsRaw() - t0 < DT_GPS_RESET_PULSE_WIDTH_US) { }
    call HW.gps_clr_reset();
  }


  /*
   * gps_hibernate: switch off gps, check to see if it is already off first
   */
  void gps_hibernate() {
    uint32_t t0;

    if (call HW.gps_awake()) {
      toggle_gps_on_off();
      t0 = call Platform.usecsRaw();
      while (call Platform.usecsRaw() - t0 < DT_GPS_ON_OFF_WIDTH_US) {
        if (!call HW.gps_awake()) return;
      }
      gps_panic(8, 1, 0);
      return;
    }
  }


  void gpsc_change_state(gpsc_state_t next_state, gps_where_t where) {
    gpsc_state = next_state;
    gpsc_log_event(GPSE_STATE, where);
  }


  /*
   * GPSControl.turnOn: start up the gps receiver chip
   */
  command error_t GPSControl.turnOn() {
    bool awake;

    if (gpsc_state != GPSC_OFF) {
      return EALREADY;
    }

    call HW.gps_pwr_on();
    awake = call HW.gps_awake();
    t_gps_pwr_on = call LocalTime.get();
    call CollectEvent.logEvent(DT_EVENT_GPS_TURN_ON, t_gps_pwr_on, awake, 0, 0);
    if (awake) {
      gpsc_change_state(GPSC_PROBE_0, GPSW_TURNON);
      call HW.gps_speed_di(GPS_TARGET_SPEED);
      call GPSRxTimer.startOneShot(0);
      return SUCCESS;
    }

    /*
     * not awake, assume we came out of POR so the gps is starting up from
     * full power on and needs more time.
     */
    call GPSTxTimer.startOneShot(DT_GPS_PWR_UP_DELAY);
    gpsc_change_state(GPSC_PWR_UP_WAIT, GPSW_TURNON);
    return SUCCESS;
  }


  /*
   * GPSControl.turnOff: Stop all GPS activity.
   *
   * NOT DONE.  Needs eval.
   */
  command error_t GPSControl.turnOff() {
    if (gpsc_state == GPSC_OFF) {
      gps_warn(10, gpsc_state, 0);
      return FAIL;
    }
    call CollectEvent.logEvent(DT_EVENT_GPS_TURN_OFF, 0, 0, 0, 0);
    call HW.gps_rx_int_disable();
    call HW.gps_send_block_stop();
    call HW.gps_receive_block_stop();
    call GPSTxTimer.stop();
    call GPSRxTimer.stop();
    m_cur_rx_len = m_req_rx_len = -1;
    gps_hibernate();
    gpsc_change_state(GPSC_OFF, GPSW_TURNOFF);
    return SUCCESS;
  }


  /*
   * GPSControl.standby: Put the GPS chip into standby.
   */
  command error_t GPSControl.standby() {
    gps_hibernate();
    call HW.gps_rx_int_disable();
    call GPSTxTimer.stop();
    call GPSRxTimer.stop();
    m_cur_rx_len = m_req_rx_len = -1;
    gpsc_change_state(GPSC_HIBERNATE, GPSW_STANDBY);
    call CollectEvent.logEvent(DT_EVENT_GPS_STANDBY, 0, 0, 0, 0);
    return SUCCESS;
  }


  command void GPSControl.hibernate() {
    gps_hibernate();
  }


  command void GPSControl.wake() {
    gps_wakeup();
  }


  command void GPSControl.pulseOnOff() {
    toggle_gps_on_off();
  }


  command bool GPSControl.awake() {
    return call HW.gps_awake();
  }


  command void GPSControl.reset() {
    gps_reset();
  }


  command void GPSControl.powerOn() {
    call HW.gps_pwr_on();
  }


  command void GPSControl.powerOff() {
    call HW.gps_pwr_off();
  }


  command void GPSControl.logStats() {
    call SirfProto.logStats();
  }


  task void collect_task() {
    call CollectEvent.logEvent(DT_EVENT_GPS_FIRST, t_gps_first_char,
                               t_gps_first_char - t_gps_pwr_on, 0, 0);
  }


  event void GPSRxErrorTimer.fired() {
    atomic {
      m_first_rx_error = 0;             /* open gate */
    }
  }


  task void collect_rx_errors() {
    atomic {
      call CollectEvent.logEvent(DT_EVENT_GPS_RX_ERR, m_first_rx_error,
                                 m_rx_errors, m_last_rpt_rx_errors, gpsc_state);
      m_last_rpt_rx_errors = m_rx_errors;
      call GPSRxErrorTimer.startOneShot(60000);
    }
  }


  uint16_t m_tx_len;

  command error_t GPSTransmit.send(uint8_t *ptr, uint16_t len) {
    gpsc_state_t next_state;
    error_t err;
    uint32_t time_out;

    if (m_tx_len)
      return EBUSY;
    atomic {
      if (gpsc_state < GPSC_ON)
        return ERETRY;

      switch (gpsc_state) {
        default:
          gps_panic(9, gpsc_state, 0);
          return FAIL;

        case GPSC_ON:       next_state = GPSC_ON_TX;    break;
        case GPSC_ON_RX:    next_state = GPSC_ON_RX_TX; break;
      }
      m_tx_len = len;
      gpsc_change_state(next_state, GPSW_TX_SEND);
    }

    /* start with full retries for tx lost interrupt backstop */
    m_lost_tx_retries = GPS_MAX_LOST_TX_RETRIES;
    time_out = len * DT_GPS_BYTE_TIME * 4 + 500000;
    time_out /= 1000000;
    if (time_out < DT_GPS_MIN_TX_TIMEOUT)
      time_out = DT_GPS_MIN_TX_TIMEOUT;
    m_tx_time_out = time_out;
    call GPSTxTimer.startOneShot(time_out);
    collect_gps_pak((void *) ptr, len, GPS_DIR_TX);
    err = call HW.gps_send_block((void *) ptr, len);
    if (err) {
      gps_panic(10, err, 0);
      return FAIL;
    }
    return SUCCESS;
  }


  default event void GPSTransmit.send_done() { }


  task void send_block_task();

  command void GPSTransmit.send_stop() {
    call HW.gps_send_block_stop();
    m_tx_len = 0;
    atomic {
      if (gpsc_state > GPSC_ON_RX)
        post send_block_task();
    }
  }


  /*
   * send_block_task
   *
   * handle gps_send_block completions.  gps_send_block_done happens at
   * interrupt level but many completion actions need to be performed
   * from task level.  This task handles that.
   */
  task void send_block_task() {
    atomic {
      switch(gpsc_state) {
        default:
          gps_panic(11, gpsc_state, 0);
          return;

        case GPSC_CHK_TX_WAIT:
          /*
           * config change went out okay.  wait for the gps chip
           * to actually process it.  ie.  turn around.
           */
          call GPSTxTimer.startOneShot(DT_GPS_TA_WAIT);
          gpsc_change_state(GPSC_CHK_TA_WAIT, GPSW_SEND_BLOCK_TASK);
          return;

        case GPSC_CHK_TX1_WAIT:
          /*
           * probe (peek_0) has gone out
           * now if the comm config string worked we are still at
           * SB-<target> and do not need a timeout modifier.
           *
           * wait for the probe response (see gps.h)
           */
          call GPSTxTimer.stop();
          call GPSRxTimer.startOneShot(DT_GPS_PEEK_RSP_TIMEOUT);
          m_cur_rx_len = SIRFBIN_PEEK_RSP_LEN;
          gpsc_change_state(GPSC_CHK_RX_WAIT, GPSW_SEND_BLOCK_TASK);
          call HW.gps_rx_int_enable();        /* turn on rx system */
          return;

        case GPSC_ON_TX:
          call GPSTxTimer.stop();
          gpsc_change_state(GPSC_ON, GPSW_SEND_BLOCK_TASK);

          /* signal out to the caller that started up the GPSTransmit.send */
          if (m_tx_len) {
            m_tx_len = 0;
            signal GPSTransmit.send_done();
          }
          return;

        case GPSC_ON_RX_TX:
          call GPSTxTimer.stop();
          gpsc_change_state(GPSC_ON_RX, GPSW_SEND_BLOCK_TASK);

          /* signal out to the caller that started up the GPSSend.send */
          if (m_tx_len) {
            m_tx_len = 0;
            signal GPSTransmit.send_done();
          }
          return;
      }
    }
  }


  /*
   * probe_task
   *
   * handles manipulation of probe cycles.
   */
  task void probe_task() {
    const uint8_t *msg;
    uint32_t       speed, len, to_mod, time_out;

    atomic {
      switch(gpsc_state) {
        default:
          gps_panic(12, gpsc_state, 0);
          return;

        case GPSC_PROBE_CYCLE:
          call GPSRxTimer.stop();       /* always stop the rx timer */

          /* starting a new cycle. */
          gps_probe_index++;
          if (gps_probe_index >= GPT_MAX_INDEX) {
            /*
             * Well that didnt work.  We have worked our way through all the
             * entries in the probe table and nothing worked.  Leave it up to
             * the higher layers as to what to do next.
             *
             * We could reset the GPS here to make sure that it isn't consuming
             * power.  But leave it up to the higher control software.
             */
            gpsc_change_state(GPSC_OFF, GPSW_PROBE_TASK);
            gpsc_boot_time = call LocalTime.get() - t_gps_pwr_on;
            call CollectEvent.logEvent(DT_EVENT_GPS_BOOT_FAIL,
                                       t_gps_pwr_on, gpsc_boot_time, 0, 0);
            signal GPSControl.gps_boot_fail();
            return;
          }

          /* fall through into PROBE_x1 and continue the PROBE */
          speed  = gps_probe_table[gps_probe_index].speed;
          to_mod = gps_probe_table[gps_probe_index].to_modifier;
          len    = gps_probe_table[gps_probe_index].len;
          msg    = gps_probe_table[gps_probe_index].msg;

          time_out = len * DT_GPS_BYTE_TIME * to_mod * 4 + 500000;
          time_out /= 1000000;
          if (!time_out) time_out = 2;    /* at least 2ms */

          /* start deadman timer, change speed, and send the puppie */
          gps_chk_trys = GPS_CHK_MAX_TRYS;
          gpsc_change_state(GPSC_CHK_TX_WAIT, GPSW_PROBE_TASK);
          gpsc_log_event(GPSE_SPEED, speed);
          call HW.gps_speed_di(speed);
          call GPSTxTimer.startOneShot(time_out);
          collect_gps_pak((void *) msg, len, GPS_DIR_TX);
          call HW.gps_send_block((void *) msg, len);
          return;
      }
    }
  }


  /*
   * gps_pwr_task
   *
   * power has changed.  If off then blow up the timers
   * and force us to OFF.
   */
  task void gps_pwr_task() {
    if (!call GPSPwr.isPowered()) {
      call GPSTxTimer.stop();
      call GPSRxTimer.stop();
      call GPSRxErrorTimer.stop();
      gpsc_change_state(GPSC_OFF, GPSW_PWR_TASK);
      call CollectEvent.logEvent(DT_EVENT_GPS_PWR_OFF, 0, 0, 0, 0);
    }
  }


  /*
   * gps_signal_task
   *
   * issue task level signals for various states.  Currently only
   * issues a gps_booted signal.
   *
   * The gps_booted signal gets issued from any of the ON states and
   * only occurs when posted.  gps_signal_task gets posted at the tail
   * end of communications boot after receiving a good message after
   * reconfiguring the comm h/w.
   */
  task void gps_signal_task() {
    atomic {
      switch(gpsc_state) {
        default:
          gps_panic(13, gpsc_state, 0);
          return;

        case GPSC_ON:
        case GPSC_ON_RX:
        case GPSC_ON_TX:
        case GPSC_ON_RX_TX:
          gpsc_boot_time = call LocalTime.get() - t_gps_pwr_on;
          call CollectEvent.logEvent(DT_EVENT_GPS_BOOT_TIME,
                                     t_gps_pwr_on, gpsc_boot_time, 0, 0);
          nop();                        /* BRK */
          signal GPSControl.gps_booted();
          return;
      }
    }
  }


  /*
   * timer_task: handle various timer modifications
   *
   * Protocol state manipulation occurs at interrupt level and thus
   * can't manipulate timers which are strictly task level.  timer_task
   * handles requests from the interrupt level for timer manipulation.
   *
   * For RxTimer modifications, we use a Do The Right Thing algorithm.
   *
   * we do not enforce strict timer discipline.  That is we don't care if
   * the rxtimer is still running from its last usage.  This is because
   * state changes are happening at interrupt level while we need to change
   * timer behaviour at task level.  So if the task level hasn't gotten
   * around to turning off the timer before the next requested RX TO is
   * needed, its no big deal.  We will just fire up the new timeout.
   *
   * We also use a req/cur model.  Cur will always reflect the length
   * of the TO in bytes of the last fired up timer operation.  Req will
   * indicate what the current request is, 0 to turn it off.
   *
   * We currently just always use MAX_RX_TIMEOUT because it is easier
   * and doesn't involve any calculations.  It is a deadman timer so we
   * really don't care.  If we later decide to tune this down the calculation
   * is:   (see gps.h)
   *
   *   to = (len * DT_GPS_BYTE_TIME * MODIFIER + 500000) / 1e6
   */
  task void timer_task() {
    atomic {                            /* don't change out from under */
      switch(gpsc_state) {
        default:
          gps_panic(14, gpsc_state, 0);
          return;

        case GPSC_CHK_MSG_WAIT:
        case GPSC_ON:
        case GPSC_ON_RX:
        case GPSC_ON_TX:
        case GPSC_ON_RX_TX:
          if (m_req_rx_len < 0)
            return;
          if (m_req_rx_len == 0) {
            m_cur_rx_len = m_req_rx_len = -1;
            call GPSRxTimer.stop();
            return;
          }
          m_cur_rx_len = m_req_rx_len;
          m_req_rx_len = -1;
          call GPSRxTimer.startOneShot(DT_GPS_MAX_RX_TIMEOUT);
          return;
      }
    }
  }


  /*
   * GPSTxTimer.fired
   *
   * General State Machine timing.  Also Tx deadman timeouts.
   */
  event void GPSTxTimer.fired() {
    atomic {
      gpsc_log_event(GPSE_TX_TIMEOUT, call Platform.usecsRaw());
      switch (gpsc_state) {
        default:                        /* all other states blow up */
          call HW.gps_hw_capture();
          nop();                        /* BRK */
          gps_panic(15, gpsc_state, 0);
          return;

        case GPSC_PWR_UP_WAIT:
          gpsc_change_state(GPSC_PROBE_0, GPSW_TX_TIMER);
          gpsc_log_event(GPSE_SPEED, GPS_TARGET_SPEED);
          call HW.gps_speed_di(GPS_TARGET_SPEED);
          gps_wakeup();                   /* wake the ARM up */
          nop();
          call GPSRxTimer.startOneShot(DT_GPS_WAKE_UP_DELAY);
          call HW.gps_rx_int_enable();        /* turn on rx system */
          return;

        case GPSC_CHK_TA_WAIT:
          /*
           * We've waited long enough for the gps chip to process the
           * configuration, now send a peek to poke the gps chip
           * (force communications).
           *
           * sirf_peek_0 always goes out at the target speed.
           *
           * We don't need to do a HW.gps_tx_finnish because we have waited
           * long enough in TA_WAIT.  This always gives the UART enough
           * time to finish sending the previous message before we change
           * the baud rate on the HW.
           */
          gpsc_change_state(GPSC_CHK_TX1_WAIT, GPSW_TX_TIMER);
          gpsc_log_event(GPSE_SPEED, GPS_TARGET_SPEED);
          call HW.gps_speed_di(GPS_TARGET_SPEED);
          call GPSTxTimer.startOneShot(DT_GPS_PEEK_TX_TIMEOUT);
          collect_gps_pak((void *) sirf_peek_0, sizeof(sirf_peek_0),
                          GPS_DIR_TX);
          call HW.gps_send_block((void *) sirf_peek_0, sizeof(sirf_peek_0));
          return;

          /*
           * The TxTimer went off and we are sending a message out,
           * oops...   We have observed a lost tx interrupt, check and
           * replace.
           */
        case GPSC_ON_TX:
        case GPSC_ON_RX_TX:
          call HW.gps_hw_capture();
          m_lost_tx_ints++;
          if (--m_lost_tx_retries >= 0) {
            call CollectEvent.logEvent(DT_EVENT_GPS_LOST_INT, m_lost_tx_ints,
                                       0, 0, m_lost_tx_retries);
            if (call HW.gps_restart_tx()) {
              call CollectEvent.logEvent(DT_EVENT_GPS_TX_RESTART,
                                         0, 0, 0, m_lost_tx_retries);
              call GPSTxTimer.startOneShot(m_tx_time_out);
              return;
            }
            gps_panic(15, -1, -1);
          }
          gps_panic(15, -1, m_lost_tx_ints);
      }
    }
  }


  /*
   * GPSRxTimer.fired - handle receive state machine related timeouts
   */
  event void GPSRxTimer.fired() {
    atomic {
      m_cur_rx_len = -1;                /* no cur running */
      switch (gpsc_state) {
        default:
          gps_panic(16, gpsc_state, 0);
          return;

        case GPSC_PROBE_0:                  /* target speed (from PWR_UP_WAIT) */
          call HW.gps_rx_int_disable();
          gps_probe_index = -1;             /* first peek try */
          gps_chk_trys    = GPS_CHK_MAX_TRYS;
          gpsc_change_state(GPSC_CHK_TX1_WAIT, GPSW_RX_TIMER);
          call GPSTxTimer.startOneShot(DT_GPS_PEEK_TX_TIMEOUT);
          collect_gps_pak((void *) sirf_peek_0, sizeof(sirf_peek_0),
                          GPS_DIR_TX);
          call HW.gps_send_block((void *) sirf_peek_0, sizeof(sirf_peek_0));
          return;

        case GPSC_CHK_RX_WAIT:
          /* never saw the start of a message, nada, probe cycle */
          call HW.gps_rx_int_disable();
          gpsc_change_state(GPSC_PROBE_CYCLE, GPSW_RX_TIMER);
          post probe_task();
          return;

        case GPSC_CHK_MSG_WAIT:
          call HW.gps_rx_int_disable();
          call SirfProto.rx_timeout();          /* tell protocol state machine */
          if (--gps_chk_trys) {
            /*
             * still have some trys left
             * go into CHK_TA_WAIT and immediately force a TxTimer expire.
             * this will effectively do a jump into the code that sends
             * the PEEK and we will try again.
             */
            gpsc_change_state(GPSC_CHK_TA_WAIT, GPSW_RX_TIMER);
            call GPSTxTimer.startOneShot(0);
            return;
          }

          /* no trys left, blow it up, and try a different config */
          gpsc_change_state(GPSC_PROBE_CYCLE, GPSW_RX_TIMER);
          post probe_task();
          return;

        case GPSC_ON_RX:
          call SirfProto.rx_timeout();
          gpsc_change_state(GPSC_ON, GPSW_RX_TIMER);
          return;

        case GPSC_ON_RX_TX:
          call SirfProto.rx_timeout();
          gpsc_change_state(GPSC_ON_TX, GPSW_RX_TIMER);
          return;
      }
    }
  }


  async event void SirfProto.msgStart(uint16_t len) {
    gpsc_state_t next_state;

    switch(gpsc_state) {
      default:
        gps_panic(17, gpsc_state, 0);
        return;

      case GPSC_CHK_RX_WAIT:
        gpsc_change_state(GPSC_CHK_MSG_WAIT, GPSW_PROTO_START);
        return;

      case GPSC_PROBE_0:
        gps_chk_trys = GPS_CHK_MAX_TRYS;
        next_state   = GPSC_CHK_MSG_WAIT;
        break;
      case GPSC_ON:      next_state = GPSC_ON_RX;         break;
      case GPSC_ON_TX:   next_state = GPSC_ON_RX_TX;      break;
    }
    m_req_rx_len = len;                 /* request rx timeout start */
    post timer_task();
    gpsc_change_state(next_state, GPSW_PROTO_START);
  }


  async event void SirfProto.msgEnd() {
    gpsc_state_t next_state;

    switch(gpsc_state) {
      default:
        gps_panic(19, gpsc_state, 0);
        return;

      case GPSC_CHK_MSG_WAIT:
        next_state = GPSC_ON;        /* rx interrupts are already on .. yum */
        post gps_signal_task();      /* tell the upper layer we be good.    */
        break;                       /* and kick the msg timer off          */

      case GPSC_ON_RX:    next_state = GPSC_ON;    break;
      case GPSC_ON_RX_TX: next_state = GPSC_ON_TX; break;
    }
    m_req_rx_len = 0;                /* request a cancel */
    post timer_task();
    gpsc_change_state(next_state, GPSW_PROTO_END);
  }


  void driver_protoAbort(uint16_t reason) {
    gpsc_state_t next_state;

    gpsc_log_event(GPSE_ABORT, reason);
    switch(gpsc_state) {
      default:
        gps_panic(18, gpsc_state, 0);
        return;

      case GPSC_CHK_MSG_WAIT:
        call HW.gps_rx_int_disable();
        gpsc_change_state(GPSC_PROBE_CYCLE, GPSW_PROTO_ABORT);
        post probe_task();
        return;

        /*
         * during various states we ignore the protoAbort.  Didn't get far
         * enough to generate the msgStart.  So just ignore it
         */
      case GPSC_PROBE_0:                /* ignore */
      case GPSC_CHK_RX_WAIT:
      case GPSC_ON:
      case GPSC_ON_TX:    return;

        /*
         * something went wrong after we got the msgStart.
         */
      case GPSC_ON_RX:    next_state = GPSC_ON;    break;
      case GPSC_ON_RX_TX: next_state = GPSC_ON_TX; break;
    }
    m_req_rx_len = 0;                   /* request a cancel */
    post timer_task();
    gpsc_change_state(next_state, GPSW_PROTO_ABORT);
  }


  async event void SirfProto.protoAbort(uint16_t reason) {
    driver_protoAbort(reason);
  }


  /*
   * underlying h/w layer is telling us there is an rx error.
   * Signaller is responsible for clearing it.
   *
   * errors have been translated from h/w specific to errors
   * defined in gpsproto.h.   For signalling with SirfProto.rx_error.
   */
  async event void HW.gps_rx_err(uint16_t gps_errors, uint16_t raw_errors) {
    m_rx_errors++;
    if (!m_first_rx_error) {
      m_first_rx_error = raw_errors;
      post collect_rx_errors();
    }
    call SirfProto.rx_error(gps_errors);
    driver_protoAbort(0);               /* 0 means rx_err */
  }


  async event void HW.gps_byte_avail(uint8_t byte) {
#ifdef GPS_EAVESDROP
    if (!t_gps_first_char) {
      t_gps_first_char = call LocalTime.get();
      post collect_task();
    }
    gbuf[g_idx++] = byte;
    if (g_idx >= GPS_EAVES_SIZE)
      g_idx = 0;
#endif
    call SirfProto.byteAvail(byte);
  }


  async event void HW.gps_send_block_done(uint8_t *ptr, uint16_t len, error_t error) {
    send_block_done_usecs = call Platform.usecsRaw();
    gpsc_log_event(GPSE_TX_POST, 0);
    post send_block_task();
  }

  async event void GPSPwr.pwrOn()  { }

  async event void GPSPwr.pwrOff() {
    post gps_pwr_task();
  }

  async event void HW.gps_receive_block_done(uint8_t *ptr, uint16_t len, error_t error) { }

        event void Collect.collectBooted() { }
  async event void Panic.hook() { }

  default event void GPSControl.standbyDone()   { };
  default event void GPSControl.gps_boot_fail() { };
  default event void GPSControl.gps_booted()    { };
  default event void GPSControl.gps_shutdown()  { };
  event void Collect.resyncDone(error_t err, uint32_t offset) { }
}
