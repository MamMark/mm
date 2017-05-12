/*
 * Copyright (c) 2008-2010 Eric B. Decker
 * Copyright (c) 2017 Eric B. Decker, Daniel J. Maltbie
 * All rights reserved.
 *
 * Redistribution and use in source and binary forms, with or without
 * modification, are permitted provided that the following conditions
 * are met:
 *
 * - Redistributions of source code must retain the above copyright
 *   notice, this list of conditions and the following disclaimer.
 *
 * - Redistributions in binary form must reproduce the above copyright
 *   notice, this list of conditions and the following disclaimer in the
 *   documentation and/or other materials provided with the
 *   distribution.
 *
 * - Neither the name of the copyright holders nor the names of
 *   its contributors may be used to endorse or promote products derived
 *   from this software without specific prior written permission.
 *
 * THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS
 * "AS IS" AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT
 * LIMITED TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS
 * FOR A PARTICULAR PURPOSE ARE DISCLAIMED.  IN NO EVENT SHALL
 * THE COPYRIGHT HOLDER OR CONTRIBUTORS BE LIABLE FOR ANY DIRECT,
 * INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES
 * (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR
 * SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION)
 * HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT,
 * STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE)
 * ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED
 * OF THE POSSIBILITY OF SUCH DAMAGE.
 *
 * @author Eric B. Decker (cire831@gmail.com)
 * @author Daniel J. Maltbie (dmaltbie@daloma.org)
 *
 * Dedicated usci uart port.
 * refactored 1/26/2017 for mm6a, dev6a, port abstraction
 * originally based on UART sirf3 driver.  rewritten for
 * SirfStarIV using UART and Port abstraction.
 */

#include <panic.h>
#include <platform_panic.h>
#include <gps.h>
#include <sirf.h>

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
 * https://www.origingps.com/wp-content/uploads/2016/07/ORG4472-Datasheet-C02-1.pdf
 *
 * The ORG4472 is another GSD4e chip that we used earlier in the
 * development process.  The Antenova M10478 is what we are using now and
 * is another GSD4e based gps chip.  It seems to be essentially the same as
 * the ORG4472.  The M10478 documentation sucks so doesn't take much for
 * the ORG documentation to be better.
 *
 * After power is applied, the gps chip needs to let power stabilize and
 * then will start up its RTC.  When things are good it will assert AWAKE
 * for 300us.  This is the initial AWAKE pulse (AWAKE_0).  Only after
 * AWAKE_0, are we allowed to try to talk to the chip.  Prior to this, the
 * chip will ignore us.
 *
 * So we want at a minimum deltaT0 (power stabilization, ~300ms) + deltaT6
 * the pulse width of AWAKE_0 (~300ms).  But there appears to be some
 * unaccounted for time between the end of deltaT0 and the rising edge of
 * AWAKE_0.  So this will have to be observed.
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
 * power off.
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
 * We currently don't have any information about the behaviour of the gps
 * chip when transitioning between HIBERNATE and ON for the different
 * operational modes.
 *
 *
 * *** Startup communications.
 *
 * Anytime the GPS transitions out of OFF we first want to make sure that
 * we can communicate with the chip.  This could be done when we first boot
 * and then we could assume that the GPS can still communicate but the
 * overhead of verifing communications isn't that bad.
 *
 * If the GPS is in some other state when we turnOn (typically HIBERNATE), we
 * assume that we can already communicate properly.
 *
 * SirfBin is abbreviated SB, NMEA as NM.  When changing the comm configuration,
 * we use "Set Binary Serial Port" (MID134, 0x86) and for NMEA we use "Set
 * Serial Port" ($PSRF100).
 *
 * The target comm configuration we want is SB-<target>, where target is the
 * operational baud rate, 115200 initially but could be higher if we need
 * the performance.
 *
 * When doing a COMM_CHECK sequence, we first start with a SB-<target> message.
 * We follow this configuration message up by sending a SB-SendSWVer message
 * which always elicits a response.  We also want to grab the current version
 * of what chip we are running.  (done).
 *
 * If the initial COMM_CHECK doesn't work (it gets a RX timeout), we then
 * proceed to send configuration messages at different baud rates for predicted
 * modes the gps chip may be in.  These configuration messages, assume the
 * GPS chip is in a particular comm configuration and will change the config
 * to SB-<target>.
 *
 * If a configuration message results in an immediate response then we
 * leave it at that.  Otherwise we also send a SB-SendSWVer to make
 * sure we can hear the GPS after setting the new configuration.
 *
 *
 * *** State Machine Description
 *
 * FAIL             gps has failed.
 * OFF              gps power is off?  Or we rebooted.
 * HIBERNATE        sleeping.
 *
 * PWR_UP_WAIT:     delay waiting for initial power on window
 *
 * PROBE_0:         wakeup wait, then send sw_ver at target baud to elicit
 *                  a packet from the gps.
 *
 * PROBE_CYCLE:     start a new probe cycle, send the next configuration we
 *                  want to try.  If we've run out, try doing them all again
 *                  after resetting.
 *
 * PROBE_x1:        psuedo state, if we haven't run out of configs to try.
 *                  actually sets the new speed and sends the config.
 *
 * CHK_TX_WAIT:     We are actively transmitting (via tx interrtups) the
 *                  current probe (which trys to change the comm
 *                  configuration).  The tx_timer is a deadman and shouldn't
 *                  go off.  Proper termination is via HW.gps_send_block_done.
 *
 * CHK_TX1_WAIT:    We may have to force a response from the gps to see if
 *                  the configuration worked.  TX1_WAIT is active while
 *                  we are sending this message.  tx_timer should not
 *                  expire.
 *
 * CHK_RX_WAIT:     Waiting to receive the response from the probe.  If
 *                  rx_timer expires we assume the probe didn't work and
 *                  we cycle to a different configuration.
 *
 * CHK_FINI_WAIT:   msgStart from the protocol engine will transition us
 *                  into FINI_WAIT where we are waiting for the message
 *                  to finish being received.
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
 * In varous places we fire up timer to make sure we don't hang.  We use
 * various timeout deadman or rx window values to set these timers to.
 * These values are computed based on what baud rate we are running and
 * how long the message is.
 *
 * We express these timeout values in terms of the target baud.  For example
 * when we are using messages out of the probe_table, there is a to_mod,
 * (time out modifier) associated with each entry.
 *
 * The formula for a calulated transit time (in msecs) is:
 *
 *    T_t = (len * byte_time * to_mod + 500000)/1000000
 *
 * len is length in bytes, byte_time is byte_time in nano secs and to_mod
 * is the ratio of target/actual, ie.  115200/4800 = ~24 for 4800 baud.
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
 *
 * Currently, the only timers used are deadman timers to detect faults and
 * things not working.  As such it really isn't that important to get the right
 * value dialed in as long as the timeout value is long enough.  So we use fixed
 * large values when in any state other.
 */

typedef enum {
  GPSC_OFF  = 0,                        /* pwr is off */
  GPSC_FAIL = 1,
  GPSC_HIBERNATE,

  GPSC_PWR_UP_WAIT,                     /* power up delay */
  GPSC_PROBE_0,
  GPSC_PROBE_CYCLE,

  /* PROBE_x1 is a psudo state.  PROBE_CYCLE alwasy drops
     immediately into it.  never actually gets set */
  GPSC_PROBE_x1,

  GPSC_CHK_TX_WAIT,
  GPSC_CHK_TX1_WAIT,
  GPSC_CHK_RX_WAIT,
  GPSC_CHK_FINI_WAIT,

  GPSC_RESET_WAIT,                      /* reset dwell */

  GPSC_CONFIG,
  GPSC_CONFIG_WAIT,

  GPSC_ON,                              // at msg boundary
  GPSC_ON_RX,                           // in receive
  GPSC_ON_RX_TX,                        // transmitting and receiving
  GPSC_ON_TX,                           // in middle of transmitting
} gpsc_state_t;                         // gps control state


typedef enum {
  GPSW_NONE = 0,
  GPSW_TURNON,
  GPSW_TURNOFF,
  GPSW_STANDBY,
  GPSW_GPS_TASK,
  GPSW_TX_TIMER,
  GPSW_RX_TIMER,
  GPSW_PROTO,
} gps_where_t;


/*
 * gpsc_state: current state of the driver state machine
 */
norace gpsc_state_t	    gpsc_state;

/* instrumentation */
uint32_t		    gpsc_boot_time;		// time it took to boot.
uint32_t		    gpsc_cycle_time;		// time last cycle took
uint32_t		    gpsc_max_cycle;		// longest cycle time.
uint32_t		    t_gps_first_char;

#ifdef GPS_LOG_EVENTS

norace uint16_t g_idx;                  /* index into gbuf */

#ifdef GPS_EAVESDROP
#define GPS_EAVES_SIZE 2048

norace uint8_t  gbuf[GPS_EAVES_SIZE];
#endif

typedef struct {
  uint32_t     ts;
  gpsc_state_t gc_state;
  gps_where_t  where;
  uint16_t     g_idx;
} gps_event_t;

#define GPS_MAX_EVENTS 32

gps_event_t g_evs[GPS_MAX_EVENTS];
uint8_t g_nev;			// next gps event

#endif   // GPS_LOG_EVENTS

/*
 * gps_probe_table
 *
 * The probe_table holds various comm configuration messages.
 *
 * Initially we assume the GPS is at SB-<target>.  We set our h/w to the
 * target baud and throw a send_sw_ver at the gps chip to see if we are
 * communicating properly.  This corresponds to probe_index -1.
 *
 * But if that doesn't work we go to probe_index 0 and start with
 * the first entry in the table to see if we can find a configuration
 * that works.
 *
 * The 1st entry in the table should be the one that is most likely
 * to work.
 *
 * Entries in the probe_table are configurations that might correspond to
 * how the gps chip is configured.
 *
 * If we run through the entire probe_table without success, we reset
 * the GPS and try again.  If that fails we give up.
 *
 * When we have found a configuration that works, as our last bit will
 * send a SB-send_sw_ver.  We want to log the SW version of the chip
 * for record keeping.
 */

#define GPT_MAX_INDEX 4

/* FIXME: is this in rom like we expect? */
const gps_probe_entry_t gps_probe_table[GPT_MAX_INDEX] = {
/*   rate mod             len                msg   */
  {  4800, 24, sizeof(nmea_sirf_115200), nmea_sirf_115200   },
  {  9600, 12, sizeof(nmea_sirf_115200), nmea_sirf_115200   },
  { 57600,  2, sizeof(nmea_sirf_115200), nmea_sirf_115200   },
  { 57600,  2, sizeof(sirf_115200),      sirf_115200        },
};

       int32_t  gps_probe_index;        // keeps track of which table entry to use
       uint32_t gps_probe_cycle;        // how many times through the list.
norace uint32_t gps_booting;            // system is booting.


/*
 * Gsd4eUP - module implementation
 */
module Gsd4eUP {
  provides {
    interface GPSState;
    interface Boot as GPSBoot;          /* outBoot */
  }
  uses {
    interface Boot;
    interface Gsd4eUHardware as HW;

    /*
     * This module uses two timers, GPSTxTimer and GPSRxTimer.
     *
     * GPSTxTimer primarily transmit deadman timing.  Also used
     *            for various state machine functions.
     * GPSRxTimer receive deadman timing.
     */
    interface Timer<TMilli> as GPSTxTimer;
    interface Timer<TMilli> as GPSRxTimer;
    interface LocalTime<TMilli>;

    interface GPSProto as SirfProto;

    interface Panic;
    interface Platform;
//  interface Trace;
//  interface LogEvent;
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
   * req_rx_len and post rxtimer_task.  cur_rx_len indicates what we were
   * last set to.
   *
   * To kill the rx_timer, set req_rx_len to 0 and post rxtimer_task.
   */
  norace int16_t m_req_rx_len;          // requested rx len (for timeout)
         int16_t m_cur_rx_len;          // cur       rx len (for timeout)


  void gps_warn(uint8_t where, parg_t p, parg_t p1) {
    call Panic.warn(PANIC_GPS, where, p, p1, 0, 0);
  }

  void gps_panic(uint8_t where, parg_t p, parg_t p1) {
    call Panic.panic(PANIC_GPS, where, p, p1, 0, 0);
  }


  /* log state */
  void gpsc_log_state(gpsc_state_t next_state, gps_where_t where) {
#ifdef GPS_LOG_EVENTS
    uint8_t idx;

    atomic {
      idx = g_nev++;
      if (g_nev >= GPS_MAX_EVENTS)
	g_nev = 0;
      g_evs[idx].ts = call LocalTime.get();
      g_evs[idx].gc_state = next_state;
      g_evs[idx].where = where;
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
      return;
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
      while (call Platform.usecsRaw() - t0 < DT_GPS_ON_OFF_WIDTH) {
        if (!call HW.gps_awake()) return;
      }
      gps_panic(8, 1, 0);
      return;
    }
  }


  void gpsc_change_state(gpsc_state_t next_state, gps_where_t where) {
    gpsc_log_state(next_state, where);
    gpsc_state = next_state;
  }


  /*
   * Boot.booted:
   */
  event void Boot.booted() {
//    call LogEvent.logEvent(DT_EVENT_GPS_BOOT,0);
    gpsc_change_state(GPSC_OFF, GPSW_NONE);
    gps_booting = 1;
    call GPSState.turnOn();
  }


  /*
   * GPSState.turnOn: start up the gps receiver chip
   */
  command error_t GPSState.turnOn() {
    if (gpsc_state != GPSC_OFF) {
      gps_warn(9, gpsc_state, 0);
      return FAIL;
    }
//    call LogEvent.logEvent(DT_EVENT_GPS_START, 0);
    t_gps_pwr_on = call LocalTime.get();
    gps_probe_cycle = 0;
    call HW.gps_pwr_on();
    gps_reset();
    call GPSTxTimer.startOneShot(DT_GPS_PWR_UP_DELAY);
    gpsc_change_state(GPSC_PWR_UP_WAIT, GPSW_TURNON);
    return SUCCESS;
  }


  /*
   * GPSState.turnOff: Stop all GPS activity.
   */
  command error_t GPSState.turnOff() {
    if (gpsc_state == GPSC_OFF) {
      gps_warn(10, gpsc_state, 0);
      return FAIL;
    }
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
   * GPSState.standby: Put the GPS chip into standby.
   */
  command error_t GPSState.standby() {
    gps_hibernate();
    call HW.gps_rx_int_disable();
    call GPSTxTimer.stop();
    call GPSRxTimer.stop();
    m_cur_rx_len = m_req_rx_len = -1;
    gpsc_change_state(GPSC_HIBERNATE, GPSW_STANDBY);
    return SUCCESS;
  }


  /*
   * gps_task
   *
   * handles events from the async HW level like HW.gps_send_done and we
   * need to do processing at the task level.
   *
   * handles sequencing COMM checking/probing.
   */
  task void gps_task() {
    const uint8_t *msg;
    uint32_t       speed, len, to_mod, time_out;

    atomic {
      switch(gpsc_state) {
        default:
          gps_panic(11, gpsc_state, 0);
          return;

        case GPSC_PROBE_CYCLE:
          /* starting a new cycle. */
          gps_probe_index++;
          if (gps_probe_index >= GPT_MAX_INDEX) {
            /* well that didn't work, we tried all the entries */
            gps_probe_index = 0;
            gps_probe_cycle++;
            if (gps_probe_cycle >= 2) {
              /* last cycle we hit reset but still didn't find anything */
              gps_panic(11, gpsc_state, 0);
              return;
            }
            /* okay, 1st cycle didn't work, kick reset and try again */
            gps_warn(11, gpsc_state, 0);
            gps_reset();
            call GPSTxTimer.startOneShot(DT_GPS_PWR_UP_DELAY);
            gpsc_change_state(GPSC_PWR_UP_WAIT, GPSW_RX_TIMER);
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
          gpsc_change_state(GPSC_CHK_TX_WAIT, GPSW_GPS_TASK);

          /* start deadman timer, change speed, and send the puppie */
          call GPSTxTimer.startOneShot(time_out);
          call HW.gps_speed_di(speed);
          call HW.gps_send_block((void *) msg, len);
          return;

        case GPSC_CHK_TX_WAIT:
          /*
           * first part went, the configuration change
           * so now send out the send_sw_ver to force a response
           *
           * send_sw_ver always goes out at the target speed.
           */
          gpsc_change_state(GPSC_CHK_TX1_WAIT, GPSW_GPS_TASK);
          call HW.gps_tx_finnish();
          call HW.gps_speed_di(GPS_TARGET_SPEED);

          /* start deadman timer, and send sw_ver */
          call GPSTxTimer.startOneShot(SWVER_TX_TIMEOUT);
          call HW.gps_send_block((void *) sirf_send_sw_ver, sizeof(sirf_send_sw_ver));
          return;

        case GPSC_CHK_TX1_WAIT:
          /*
           * send_sw_ver has gone out
           * now if the comm config string worked we will now be at
           * SB-<target> and no longer need any timeout modifiers.
           *
           * wait for the maximal sized sw_ver string, (80 chars + overhead)
           * times 4 (to give a big window, its a deadman remember).  We
           * just use MAX_RX_TIMEOUT.
           */
          call GPSTxTimer.stop();
          call GPSRxTimer.startOneShot(MAX_RX_TIMEOUT);
          m_cur_rx_len = SIRFBIN_MAX_SW_VER;
          gpsc_change_state(GPSC_CHK_RX_WAIT, GPSW_GPS_TASK);
          call HW.gps_rx_int_enable();        /* turn on rx system */
          return;

        case GPSC_ON:
        case GPSC_ON_RX:
          if (gps_booting) {
            gps_booting = 0;
            signal GPSBoot.booted();
          }
          return;

        case GPSC_ON_TX:
          /* here because got a HW.gps_send_block_done */
          gpsc_change_state(GPSC_ON, GPSW_GPS_TASK);
          call GPSTxTimer.stop();
          /* signal out to the caller that started up the GPSSend.send */
          return;

        case GPSC_ON_RX_TX:
          /* here because got a HW.gps_send_block_done */
          gpsc_change_state(GPSC_ON_RX, GPSW_GPS_TASK);
          call GPSTxTimer.stop();
          /* signal out to the caller that started up the GPSSend.send */
          return;
      }
    }
  }


  /*
   * handle setting the deadman rx timer
   *
   * we use a Do The Right Thing algorithm.
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
   * We currently just always .use MAX_RX_TIMEOUT because it is easier
   * and doesn't involve any calculations.  It is a deadman timer so we
   * really don't care.  If we later decide to tune this down the calculation
   * is:   (see gps.h)
   *
   *   to = (len * DT_GPS_BYTE_TIME * MODIFIER + 500000) / 1e6
   */
  task void rxtimer_task() {
    atomic {                            /* don't change out from under */
      switch(gpsc_state) {
        default:                        /* ignore other states */
          return;

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
          call GPSRxTimer.startOneShot(MAX_RX_TIMEOUT);
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
      switch (gpsc_state) {
        default:                        /* all other states blow up */
          gps_panic(12, gpsc_state, 0);
          return;

        case GPSC_PWR_UP_WAIT:
          gps_wakeup();                   /* wake the ARM up */
          call GPSTxTimer.startOneShot(DT_GPS_WAKE_UP_DELAY);
          gpsc_change_state(GPSC_PROBE_0, GPSW_TX_TIMER);
          return;

        case GPSC_PROBE_0:
          gps_probe_index = -1;            /* first sw_ver try */
          gpsc_change_state(GPSC_CHK_TX1_WAIT, GPSW_TX_TIMER);
          call HW.gps_speed_di(GPS_TARGET_SPEED);
          call GPSTxTimer.startOneShot(SWVER_TX_TIMEOUT);
          call HW.gps_send_block((void *)sirf_send_sw_ver, sizeof(sirf_send_sw_ver));
          return;
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
          gps_panic(14, gpsc_state, 0);
          return;

        case GPSC_CHK_RX_WAIT:
        case GPSC_CHK_FINI_WAIT:
          call HW.gps_rx_int_disable();
          gpsc_change_state(GPSC_PROBE_CYCLE, GPSW_RX_TIMER);
          post gps_task();
          return;

        case GPSC_ON_RX:
          call SirfProto.reset();
          gpsc_change_state(GPSC_ON, GPSW_RX_TIMER);
          return;

        case GPSC_ON_RX_TX:
          call SirfProto.reset();
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
        gpsc_change_state(GPSC_CHK_FINI_WAIT, GPSW_PROTO);
        return;
      case GPSC_ON:    next_state = GPSC_ON_RX;    break;
      case GPSC_ON_TX: next_state = GPSC_ON_RX_TX; break;
    }
    m_req_rx_len = len;                 /* request rx timeout start */
    post rxtimer_task();
    gpsc_change_state(next_state, GPSW_PROTO);
  }


  async event void SirfProto.msgAbort() {
    gpsc_state_t next_state;

    switch(gpsc_state) {
      default:
        gps_panic(18, gpsc_state, 0);
        return;
      case GPSC_CHK_FINI_WAIT:
        call HW.gps_rx_int_disable();
        gpsc_change_state(GPSC_PROBE_CYCLE, GPSW_PROTO);
        post gps_task();
        return;
      case GPSC_ON_RX:    next_state = GPSC_ON;    break;
      case GPSC_ON_RX_TX: next_state = GPSC_ON_TX; break;
    }
    m_req_rx_len = 0;                   /* request a cancel */
    post rxtimer_task();
    gpsc_change_state(next_state, GPSW_PROTO);
  }


  async event void SirfProto.msgEnd() {
    gpsc_state_t next_state;

    m_req_rx_len = 0;                   /* request a cancel */
    post rxtimer_task();
    switch(gpsc_state) {
      default:
        gps_panic(19, gpsc_state, 0);
        return;
      case GPSC_CHK_FINI_WAIT:
        if (gps_booting)
          post gps_task();              /* do a little bit extra */

        /* fall through */

      case GPSC_ON_RX:    next_state = GPSC_ON;    break;
      case GPSC_ON_RX_TX: next_state = GPSC_ON_RX; break;
    }
    gpsc_change_state(next_state, GPSW_PROTO);
  }


  async event void HW.gps_byte_avail(uint8_t byte) {
#ifdef GPS_EAVESDROP
    gbuf[g_idx++] = byte;
    if (g_idx >= GPS_EAVES_SIZE)
      g_idx = 0;
#endif
    call SirfProto.byteAvail(byte);
  }


  async event void HW.gps_send_block_done(uint8_t *ptr, uint16_t len, error_t error) {
    post gps_task();
  }

  async event void HW.gps_receive_block_done(uint8_t *ptr, uint16_t len, error_t error) { }

  async event void Panic.hook() { }
}
