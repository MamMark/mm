/*
 * Copyright (c) 2020,     Eric B. Decker
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
 */

#include <panic.h>
#include <platform_panic.h>
#include <gps_ublox.h>
#include <ublox_driver.h>
#include <typed_data.h>
#include <overwatch.h>

#ifndef PANIC_GPS
enum {
  __pcode_gps = unique(UQ_PANIC_SUBSYS)
};

#define PANIC_GPS __pcode_gps
#endif

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
#define GPS_EAVES_SIZE 2048

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
uint8_t g_nev;                          // next gps event

#endif   // GPS_LOG_EVENTS


norace uint32_t gps_chk_trys;           // remaining chk_msgs to try  CHK_MSG_WAIT

module ubloxZoeP {
  provides {
    interface GPSControl;
    interface MsgTransmit;
  }
  uses {
    interface ubloxHardware as HW;

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

    interface GPSProto as ubxProto;

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
         uint32_t m_tx_time_out;        // last tx timeout used

#define GPS_MAX_LOST_TX_RETRIES 5

  void gps_warn(uint8_t where, parg_t p, parg_t p1) {
    call Panic.warn(PANIC_GPS, where, p, p1, 0, 0);
  }

  void gps_panic(uint8_t where, parg_t p, parg_t p1) {
    call Panic.panic(PANIC_GPS, where, p, p1, 0, 0);
  }


  void clean_port_errors() {
    atomic {
      m_rx_errors = 0;
      m_last_rpt_rx_errors = 0;
      m_first_rx_error = 0;
      m_last_rx_collection = 0;
      m_lost_tx_ints = 0;
    }
  }


  /* collect_gps_pak
   *
   * add a gps packet to the data stream.  Debugging etc.
   */
  static void collect_gps_pak(uint8_t *pak, uint16_t len, uint8_t dir) {
    dt_gps_t hdr;

    if (call OverWatch.getLoggingFlag(OW_LOG_GPS_RAW)) {
      hdr.len      = sizeof(hdr) + len;
      hdr.dtype    = DT_GPS_RAW;
      hdr.mark_us  = 0;
      hdr.chip_id  = CHIP_GPS_ZOE;
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


  void gps_wakeup() {
  }


  void gps_reset() {
  }


  /*
   * gps_hibernate: switch off gps, check to see if it is already off first
   */
  void gps_hibernate() {
  }


  void gpsc_change_state(gpsc_state_t next_state, gps_where_t where) {
    gpsc_state = next_state;
    gpsc_log_event(GPSE_STATE, where);
  }


  /*
   * GPSControl.turnOn: start up the gps receiver chip
   */
  command error_t GPSControl.turnOn() {
    if (gpsc_state != GPSC_OFF) {
      return EALREADY;
    }

    call HW.gps_speed_di(9600);
    call HW.gps_pwr_on();
    t_gps_pwr_on = call LocalTime.get();
    call CollectEvent.logEvent(DT_EVENT_GPS_TURN_ON, t_gps_pwr_on, 0, 0, 0);

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
   */
  command error_t GPSControl.turnOff() {
    if (gpsc_state == GPSC_OFF) {
      gps_warn(10, gpsc_state, 0);
    }
    call CollectEvent.logEvent(DT_EVENT_GPS_TURN_OFF, 0, 0, 0, 0);
    call HW.gps_rx_int_disable();
    call HW.gps_send_block_stop();
    call HW.gps_receive_block_stop();
    call GPSTxTimer.stop();
    call GPSRxTimer.stop();
    m_cur_rx_len = m_req_rx_len = -1;
    call HW.gps_pwr_off();
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
  }


  command bool GPSControl.awake() {
    return 0;
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
    call ubxProto.logStats();
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

  command error_t MsgTransmit.send(uint8_t *ptr, uint16_t len) {
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


  default event void MsgTransmit.send_done() { }


  task void send_block_task();

  command void MsgTransmit.send_stop() {
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
           * wait for the probe response (see gps_gsd4e.h)
           */
          call GPSTxTimer.stop();
          call GPSRxTimer.startOneShot(100);
          m_cur_rx_len = 20;
          gpsc_change_state(GPSC_CHK_RX_WAIT, GPSW_SEND_BLOCK_TASK);
          call HW.gps_rx_int_enable();        /* turn on rx system */
          return;

        case GPSC_ON_TX:
          call GPSTxTimer.stop();
          gpsc_change_state(GPSC_ON, GPSW_SEND_BLOCK_TASK);

          /* signal out to the caller that started up the MsgTransmit.send */
          if (m_tx_len) {
            m_tx_len = 0;
            signal MsgTransmit.send_done();
          }
          return;

        case GPSC_ON_RX_TX:
          call GPSTxTimer.stop();
          gpsc_change_state(GPSC_ON_RX, GPSW_SEND_BLOCK_TASK);

          /* signal out to the caller that started up the GPSSend.send */
          if (m_tx_len) {
            m_tx_len = 0;
            signal MsgTransmit.send_done();
          }
          return;
      }
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
   * is:   (see gps_gsd4e.h)
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
          call GPSTxTimer.startOneShot(20);
//          collect_gps_pak((void *) sirf_peek_0, sizeof(sirf_peek_0),
//                          GPS_DIR_TX);
//          call HW.gps_send_block((void *) sirf_peek_0, sizeof(sirf_peek_0));
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
          return;

        case GPSC_CHK_RX_WAIT:
          /* never saw the start of a message, nada, probe cycle */
          call HW.gps_rx_int_disable();
          gpsc_change_state(GPSC_PROBE_CYCLE, GPSW_RX_TIMER);
//          post probe_task();
          return;

        case GPSC_CHK_MSG_WAIT:
          call HW.gps_rx_int_disable();
          call ubxProto.rx_timeout();          /* tell protocol state machine */
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
//          post probe_task();
          return;

        case GPSC_ON_RX:
          call ubxProto.rx_timeout();
          gpsc_change_state(GPSC_ON, GPSW_RX_TIMER);
          return;

        case GPSC_ON_RX_TX:
          call ubxProto.rx_timeout();
          gpsc_change_state(GPSC_ON_TX, GPSW_RX_TIMER);
          return;
      }
    }
  }


  async event void ubxProto.msgStart(uint16_t len) {
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


  async event void ubxProto.msgEnd() {
    gpsc_state_t next_state;

    switch(gpsc_state) {
      default:
        gps_panic(19, gpsc_state, 0);
        return;

      case GPSC_CHK_MSG_WAIT:
        call ubxProto.resetStats(); /* clear out any errors from turn on   */
        clean_port_errors();
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
//        post probe_task();
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


  async event void ubxProto.protoAbort(uint16_t reason) {
    driver_protoAbort(reason);
  }


  /*
   * underlying h/w layer is telling us there is an rx error.
   * Signaller is responsible for clearing it.
   *
   * errors have been translated from h/w specific to errors
   * defined in gpsproto.h.   For signalling with ubxProto.rx_error.
   */
  async event void HW.gps_rx_err(uint16_t gps_errors, uint16_t raw_errors) {
    m_rx_errors++;
    if (!m_first_rx_error) {
      m_first_rx_error = raw_errors;
      post collect_rx_errors();
    }
    call ubxProto.rx_error(gps_errors);
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
    call ubxProto.byteAvail(byte);
  }


  async event void HW.gps_send_block_done(uint8_t *ptr, uint16_t len, error_t error) {
    send_block_done_usecs = call Platform.usecsRaw();
    gpsc_log_event(GPSE_TX_POST, 0);
    post send_block_task();
  }


  async event void HW.gps_receive_block_done(uint8_t *ptr, uint16_t len, error_t error) { }

        event void Collect.collectBooted() { }
  async event void Panic.hook() { }

  default event void GPSControl.standbyDone()   { };
  default event void GPSControl.gps_boot_fail() { };
  default event void GPSControl.gps_booted()    { };
  default event void GPSControl.gps_shutdown()  { };
}
