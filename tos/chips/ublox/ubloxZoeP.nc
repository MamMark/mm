/*
 * Copyright (c) 2020-2021, Eric B. Decker
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
 * Dedicated usci spi port.
 */

#include <panic.h>
#include <platform_panic.h>
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
  GPSC_OFF              = 0,            /* pwr is off */

  /* normal operation */
  GPSC_ON               = 1,            // at msg boundary
  GPSC_ON_RX            = 2,            // in process of receiving a packet, timer on
  GPSC_ON_TX            = 3,            // doing transmit, txtimer running.
  GPSC_ON_RX_TX         = 4,            // not really used.  TX atomic

  /* pipeline restart */
  GPSC_RESTART_WAIT     = 5,            // waiting for pipeline ack

  /* bootstrap, standalone, no timers */
  GPSC_CONFIG_BOOT      = 6,            /* bootstrap initilization */
  GPSC_CONFIG_CHK       = 7,            /* configuration check     */
  GPSC_CONFIG_SET_TXRDY = 8,            /* need txrdy configured   */
  GPSC_CONFIG_TXRDY_ACK = 9,            /* waiting for ack         */
  GPSC_CONFIG_DONE      = 10,           /* good to go              */
  GPSC_CONFIG_MSG       = 11,           /* configuring msgs        */
  GPSC_CONFIG_MSG_ACK   = 12,           /* waiting for config ack  */
  GPSC_CONFIG_SAVE_ACK  = 13,           /* saving config           */
  GPSC_VER_WAIT         = 14,           /* waiting for ver string  */
  GPSC_VER_DONE         = 15,           /* found it. */

  GPSC_PWR_UP_WAIT      = 16,           /* waiting for power up    */

  GPSC_STANDBY          = 17,           /* in standby, hibernating    */
  GPSC_STANDBY_WAIT     = 18,           /* waiting to go into standby */
  GPSC_WAKE_WAIT        = 19,           /* from standby to wake wait  */

  GPSC_RESET_WAIT       = 20,           /* reset dwell */

  GPSC_FAIL             = 21,

  GPSC_PWR_DWN_WAIT     = 22,

} gpsc_state_t;                         // gps control state


typedef enum {
  GPSW_NONE = 0,
  GPSW_BOOT,
  GPSW_TURNON,
  GPSW_TURNOFF,
  GPSW_STANDBY,
  GPSW_TX_TIMER,
  GPSW_RX_TIMER,
  GPSW_PROTO_START,
  GPSW_PROTO_ABORT,
  GPSW_PROTO_END,
  GPSW_TX_SEND,
  GPSW_PIPE_RESTART,
  GPSW_WAKEUP,
} gps_where_t;


typedef enum {
  GPSE_NONE = 0,
  GPSE_STATE,                           /* state change */
  GPSE_CONFIG,                          /* config message sent */
  GPSE_CONFIG_ACK,                      /* config message acked */
  GPSE_ABORT,                           /* protocol abort */
  GPSE_TX_POST,                         /* tx h/w int posted */
  GPSE_TIMEOUT,                         /* timeout */
  GPSE_PIPE_RESTART,                    /* pipeline restart */
} gps_event_t;


enum {
  /* default tx deadman */
  GPS_TX_WAIT_DEFAULT = 2048,

  /* delay between config messages */
  GPS_TX_CONFIG_DELAY = 256,
};


/*
 * gpsc_state:  current state of the driver state machine
 * gpsc_in_msg: true if within message boundaries.
 */
norace gpsc_state_t	    gpsc_state;
norace uint32_t             gpsc_count;         /* used by repeated states */
norace bool                 gpsc_in_msg;

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
uint8_t  g_nev;                         // next gps event

#endif   // GPS_LOG_EVENTS


uint8_t ubx_nav_cfgs[] = {
  UBX_NAV_PVT,
  UBX_NAV_STATUS,
  UBX_NAV_CLOCK,
  UBX_NAV_DOP,
  UBX_NAV_SAT,
  UBX_NAV_EOE,
  0,
};


module ubloxZoeP {
  provides {
    interface Boot as Booted;           /* out Boot */
    interface GPSControl;
    interface MsgTransmit;
  }
  uses {
    interface Boot;                     /* in Boot */

    interface ubloxHardware as HW;
    interface Timer<TMilli> as GPSTxTimer;
    interface Timer<TMilli> as GPSRxTimer;
    interface LocalTime<TMilli>;

    interface MsgBuf;
    interface GPSProto as ubxProto;
    interface GPSLog;

    interface Panic;
    interface Platform;
    interface Collect;
    interface CollectEvent;
    interface OverWatch;
//  interface Trace;
  }
}
implementation {

  uint32_t t_gps_boot_start;            // when bootstrap start
  uint32_t t_gps_boot_end;              // when bootstrap complete
  uint32_t t_gps_boot_delta;            // how long boot strap takes.

  norace uint32_t m_rx_errors;          // rx errors from the h/w
         uint32_t m_lost_tx_ints;       // on_tx, time outs
         uint32_t m_lost_tx_retries;
         uint32_t m_tx_time_out;        // last tx timeout used


  void gps_warn(uint8_t where, parg_t p, parg_t p1) {
    call Panic.warn(PANIC_GPS, where, p, p1, 0, 0);
  }

  void gps_panic(uint8_t where, parg_t p, parg_t p1) {
    call Panic.panic(PANIC_GPS, where, p, p1, 0, 0);
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


  void gps_reset()  { }


  void gpsc_change_state(gpsc_state_t next_state, gps_where_t where) {
#ifdef GPS_DEBUG_STATE
    if (next_state != gpsc_state) {
      WIGGLE_TELL; WIGGLE_TELL; WIGGLE_TELL; WIGGLE_TELL; WIGGLE_TELL;
      nop(); nop(); nop(); nop(); nop(); nop(); nop(); nop(); nop(); nop();
      switch (next_state) {
        default:                        WIGGLE_TELL;
                                        WIGGLE_TELL;
        case GPSC_PWR_DWN_WAIT:         WIGGLE_TELL;
        case GPSC_FAIL:                 WIGGLE_TELL;
        case GPSC_RESET_WAIT:           WIGGLE_TELL;
        case GPSC_WAKE_WAIT:            WIGGLE_TELL;
        case GPSC_STANDBY_WAIT:         WIGGLE_TELL;
        case GPSC_STANDBY:              WIGGLE_TELL;
        case GPSC_PWR_UP_WAIT:          WIGGLE_TELL;
        case GPSC_VER_DONE:             WIGGLE_TELL;
        case GPSC_VER_WAIT:             WIGGLE_TELL;
        case GPSC_CONFIG_SAVE_ACK:      WIGGLE_TELL;
        case GPSC_CONFIG_MSG_ACK:       WIGGLE_TELL;
        case GPSC_CONFIG_MSG:           WIGGLE_TELL;
        case GPSC_CONFIG_DONE:          WIGGLE_TELL;
        case GPSC_CONFIG_TXRDY_ACK:     WIGGLE_TELL;
        case GPSC_CONFIG_SET_TXRDY:     WIGGLE_TELL;
        case GPSC_CONFIG_CHK:           WIGGLE_TELL;
        case GPSC_CONFIG_BOOT:          WIGGLE_TELL;
        case GPSC_RESTART_WAIT:         WIGGLE_TELL;
        case GPSC_ON_RX_TX:             WIGGLE_TELL;
        case GPSC_ON_TX:                WIGGLE_TELL;
        case GPSC_ON_RX:                WIGGLE_TELL;
        case GPSC_ON:                   WIGGLE_TELL;
        case GPSC_OFF:                  break;
      }
    }
#endif
    gpsc_state = next_state;
    gpsc_log_event(GPSE_STATE, where);
  }


  /*
   * GPSControl.turnOn: start up the gps receiver chip
   * used to take the chip out of power off.
   */
  command error_t GPSControl.turnOn() {
    if (gpsc_state != GPSC_OFF) {
      return EALREADY;
    }

    call HW.gps_pwr_on();
    call HW.gps_txrdy_int_enable(16);
    gpsc_change_state(GPSC_ON, GPSW_TURNON);
    call CollectEvent.logEvent(DT_EVENT_GPS_TURN_ON, 0, 0, 0, 0);
    return SUCCESS;

#ifdef notdef
    call HW.gps_txrdy_int_disable();        /* no need for it yet. */

    /* turning on the Ublox Zoe anecdotally takes about 68ms.  Give it more time */
    call GPSTxTimer.startOneShot(DT_GPS_PWR_DWN_TO);
    gpsc_change_state(GPSC_PWR_UP_WAIT, GPSW_TURNON);
    call CollectEvent.logEvent(DT_EVENT_GPS_TURN_ON, t_gps_pwr_on, 0, 0, 0);
    return SUCCESS;
#endif
  }


  /*
   * GPSControl.turnOff: Stop all GPS activity.
   */
  command error_t GPSControl.turnOff() {
    if (gpsc_state == GPSC_OFF) {
      gps_warn(10, gpsc_state, 0);
    }
    call CollectEvent.logEvent(DT_EVENT_GPS_TURN_OFF, 0, 0, 0, 0);
//    WIGGLE_TELL; WIGGLE_TELL;
    gpsc_change_state(GPSC_PWR_DWN_WAIT, GPSW_TURNOFF);
    call GPSRxTimer.stop();
    call GPSTxTimer.startOneShot(DT_GPS_PWR_DWN_TO);
//    call HW.gps_pwr_off();

    /*
     * Note: On the dev7 we don't have actual control of gps power.  When we turn off
     * the dev7 gps, pwr is kept on but we disconnect the control signals.  However
     * the txrdy int pin is still connected, when this interrupt occurs, driver_task
     * gets posted but the pipeline stalls.  (pins not connected),  Eventually this
     * causes a panic.
     *
     * This needs to be sorted out later.
     */
    return SUCCESS;
  }


  command void GPSControl.pulseOnOff() { }

  command bool GPSControl.awake()      {
    if (gpsc_state == GPSC_OFF || gpsc_state == GPSC_STANDBY)
      return FALSE;
    else
      return TRUE;
  }

  command void GPSControl.reset() { }

  command void GPSControl.powerOn() {
    call HW.gps_pwr_on();
  }

  command void GPSControl.powerOff() {
    call HW.gps_pwr_off();
  }

  command void GPSControl.logStats() {
    call ubxProto.logStats();
  }


  command void MsgTransmit.send(uint8_t *ptr, uint16_t len) {
    call GPSLog.collect(ptr, len, GPS_DIR_TX, NULL);
    call HW.gps_send((void *) ptr, len);
  }


  event void HW.gps_send_done(error_t err) {
    switch(gpsc_state) {
      default:
        gps_panic(14, gpsc_state, 0);
        return;

      case GPSC_PWR_DWN_WAIT:
        gpsc_change_state(GPSC_OFF, GPSW_TX_TIMER);
        call HW.gps_txrdy_int_disable();      /* turn on txrdy interrupt */
        signal GPSControl.gps_shutdown();
        break;

      case GPSC_ON:                     /* switch to default later */
      case GPSC_ON_RX:
      case GPSC_ON_TX:
      case GPSC_ON_RX_TX:
        call GPSTxTimer.stop();         /* turn off the TX timer, done. */
        signal MsgTransmit.send_done(SUCCESS);
        return;
    }
  }


  command void MsgTransmit.send_abort() { }
  default event void MsgTransmit.send_done(error_t err) { }


  event void GPSTxTimer.fired() {
    uint32_t txrdy;

    atomic {
      switch (gpsc_state) {
        case GPSC_PWR_DWN_WAIT:         /* time out, oops */
        default:                        /* all other states blow up */
          gps_panic(15, gpsc_state, 0);
          /* dead*/

        case GPSC_PWR_UP_WAIT:
          gpsc_log_event(GPSE_TIMEOUT, call Platform.usecsRaw());
          gpsc_change_state(GPSC_ON, GPSW_TX_TIMER);
          call HW.gps_txrdy_int_enable(17);     /* turn on txrdy interrupt */
          signal GPSControl.gps_booted();
          break;

        case GPSC_ON:
        case GPSC_ON_RX:
        case GPSC_ON_TX:
        case GPSC_ON_RX_TX:
          break;

        case GPSC_STANDBY_WAIT:
          /*
           * The sequence for standby is documented in gps_hibernate()
           *
           * We are looking for TXRDY floating high.  This happens sometime
           * after CS is deasserted after putting the chip into backup mode
           * (via msg).  This tells us we are asleep.
           */
          txrdy = call HW.gps_txrdy();
          if (txrdy) {
            gpsc_change_state(GPSC_STANDBY, GPSW_TX_TIMER);
            signal GPSControl.standbyDone();
            break;
          }

          /*
           * TXRDY is still low.  That means it is still being driven and the ublox
           * isn't asleep yet.
           *
           * This is an oops.   We keep our timeout reasonably short and use a counter
           * to handle multiple segments.   We log what we've seen.   If too many segments
           * blow up.
           */
          WIGGLE_TELL; WIGGLE_TELL; WIGGLE_EXC;
          gps_warn(11, gpsc_count, txrdy);
          if (--gpsc_count == 0)
            gps_panic(16, gpsc_count, txrdy);

          /* restart the timer and try again */
          call GPSTxTimer.startOneShot(DT_GPS_STANDBY_TO);
          break;

        case GPSC_WAKE_WAIT:
          /*
           * The sequence for standby is documented in gps_hibernate()
           */
          gpsc_change_state(GPSC_ON, GPSW_TX_TIMER);
          txrdy = call HW.gps_txrdy();
          if (txrdy) {
            /* we just woke up, strange that txrdy is up, yell */
            WIGGLE_TELL; WIGGLE_TELL; WIGGLE_EXC; WIGGLE_EXC;
            gps_warn(12, gpsc_state, txrdy);
          }
          call HW.gps_txrdy_int_enable(18);
          signal GPSControl.wakeupDone();
          break;
      }
    }
  }


  /*
   * GPSRxTimer.fired - handle receive state machine related timeouts
   */
  event void GPSRxTimer.fired() {
    atomic {
      switch (gpsc_state) {
        default:
          gps_panic(16, gpsc_state, 0);
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


  event void ubxProto.msgStart(uint16_t len) {
    gpsc_state_t next_state;

    gpsc_in_msg = TRUE;
    switch(gpsc_state) {
      default:
        gps_panic(17, gpsc_state, 0);
        return;

      case GPSC_STANDBY_WAIT:
        /*
         * saw a message while shutting down.
         * a power down request has already been spent
         * so doing anything with this message that would
         * change state isn't desirable.  Just abort the msg.
         */
        signal ubxProto.protoAbort(11);
        return;

      /* pipeline restart or bootstrap, run to completion, no time out */
      case GPSC_RESTART_WAIT:
      case GPSC_CONFIG_BOOT:            /* stay */
      case GPSC_CONFIG_CHK:
      case GPSC_CONFIG_SET_TXRDY:
      case GPSC_CONFIG_TXRDY_ACK:
      case GPSC_CONFIG_DONE:
      case GPSC_CONFIG_MSG:
      case GPSC_CONFIG_MSG_ACK:
      case GPSC_CONFIG_SAVE_ACK:
      case GPSC_VER_WAIT:
      case GPSC_VER_DONE:
        gpsc_change_state(gpsc_state, GPSW_PROTO_START);
        return;
      case GPSC_ON:      next_state = GPSC_ON_RX;         break;
      case GPSC_ON_TX:   next_state = GPSC_ON_RX_TX;      break;
    }
    call GPSRxTimer.startOneShot(DT_GPS_MAX_RX_TIMEOUT);
    gpsc_change_state(next_state, GPSW_PROTO_START);
  }


  event void ubxProto.msgEnd() {
    gpsc_state_t next_state;

    gpsc_in_msg = FALSE;
    switch(gpsc_state) {
      default:
        gps_panic(19, gpsc_state, 0);
        return;

      case GPSC_RESTART_WAIT:
      case GPSC_CONFIG_BOOT:            /* stay */
      case GPSC_CONFIG_CHK:
      case GPSC_CONFIG_SET_TXRDY:
      case GPSC_CONFIG_TXRDY_ACK:
      case GPSC_CONFIG_DONE:
      case GPSC_CONFIG_MSG:
      case GPSC_CONFIG_MSG_ACK:
      case GPSC_CONFIG_SAVE_ACK:
      case GPSC_VER_WAIT:
      case GPSC_VER_DONE:
        next_state = gpsc_state;
        break;

      case GPSC_ON_RX:    next_state = GPSC_ON;    break;
      case GPSC_ON_RX_TX: next_state = GPSC_ON_TX; break;
    }
    call GPSRxTimer.stop();
    gpsc_change_state(next_state, GPSW_PROTO_END);
  }


  void driver_protoAbort(uint16_t reason) {
    gpsc_state_t next_state;

    gpsc_in_msg = FALSE;
    gpsc_log_event(GPSE_ABORT, reason);
    switch(gpsc_state) {
      default:
        gps_panic(20, gpsc_state, 0);
        return;

      case GPSC_RESTART_WAIT:
      case GPSC_CONFIG_BOOT:
      case GPSC_CONFIG_CHK:
      case GPSC_CONFIG_SET_TXRDY:
      case GPSC_CONFIG_TXRDY_ACK:
      case GPSC_CONFIG_DONE:
      case GPSC_CONFIG_MSG:
      case GPSC_CONFIG_MSG_ACK:
      case GPSC_CONFIG_SAVE_ACK:
      case GPSC_VER_WAIT:
      case GPSC_VER_DONE:
      case GPSC_ON:
      case GPSC_STANDBY_WAIT:
        gpsc_change_state(gpsc_state, GPSW_PROTO_ABORT);
        return;

        /* something went wrong after we got the msgStart. */
      case GPSC_ON_RX:    next_state = GPSC_ON;    break;
      case GPSC_ON_RX_TX: next_state = GPSC_ON_TX; break;
    }
    call GPSRxTimer.stop();
    gpsc_change_state(next_state, GPSW_PROTO_ABORT);
  }


  event void ubxProto.protoAbort(uint16_t reason) {
    driver_protoAbort(reason);
  }


  /*
   * capture the byte in the eavesdrop buffer
   * TRUE says it matters
   * FALSE says punt
   */
  bool capture_byte(uint8_t byte) {
    if (byte == 0xff && !gpsc_in_msg) {
      /* 0xff is the idle byte, if outside of a message ignore */
      return FALSE;
    }

#ifdef GPS_EAVESDROP
    gbuf[g_idx++] = byte;
    if (g_idx >= GPS_EAVES_SIZE)
      g_idx = 0;
#endif
    return TRUE;
  }


  uint8_t *collect_pak(uint16_t *lenp) {
    rtctime_t *rtp;
    uint32_t   markp;
    uint8_t   *rx_msg;

    rx_msg = call MsgBuf.msg_next(lenp, &rtp, &markp);
    if (!rx_msg)
      gps_panic(21, 0, 0);
    call GPSLog.collect(rx_msg, *lenp, GPS_DIR_RX, rtp);
    return rx_msg;
  }

  event void HW.gps_byte_avail(uint8_t byte) {
    if (capture_byte(byte))
      call ubxProto.byteAvail(byte);
  }


  event void HW.gps_raw_collect(uint8_t *pak, uint16_t len, uint8_t dir) {
    call GPSLog.collect(pak, len, dir, NULL);
  }


  /*
   * returns TRUE if state change
   */
  bool process_byte(uint8_t byte) {
    uint8_t *rx_msg;
    uint16_t rx_len;
    bool     rtn;
    ubx_cfg_prt_t *ubx_prt;
    ubx_ack_t     *ubx_ack;
    ubx_header_t  *ubx_hdr;

    rtn = FALSE;
    if (capture_byte(byte)) {
      if (call ubxProto.byteAvail(byte)) {
        /* true return, says just completed a msg, process it */
        do {
          rx_msg = collect_pak(&rx_len);
          if (!rx_msg)
            return FALSE;
          if (rx_msg[0] == '$')         /* nmea */
            break;

          switch (gpsc_state) {
            default:
              break;

            case GPSC_CONFIG_CHK:
            case GPSC_CONFIG_SET_TXRDY:
              ubx_prt = (void *) rx_msg;
              if (ubx_prt->class   != UBX_CLASS_CFG    ||
                  ubx_prt->id      != UBX_CFG_PRT      ||
                  ubx_prt->portId  != UBX_COM_PORT_SPI)
                break;

              /*
               * if txReady is already set, transition into
               * CONFIG_DONE.  If not, CONFIG_SET_TXRDY
               */
              if (ubx_prt->txReady == UBX_TXRDY_VAL)
                gpsc_change_state(GPSC_CONFIG_DONE, GPSW_BOOT);
              else
                gpsc_change_state(GPSC_CONFIG_SET_TXRDY, GPSW_BOOT);
              rtn = TRUE;
              break;

            case GPSC_RESTART_WAIT:
            case GPSC_CONFIG_TXRDY_ACK:
              ubx_ack = (void *) rx_msg;
              if (ubx_ack->class    != UBX_CLASS_ACK    ||
                  ubx_ack->id       != UBX_ACK_ACK      ||
                  ubx_ack->len      != 2                ||
                  ubx_ack->ackClass != UBX_CLASS_CFG    ||
                  ubx_ack->ackId    != UBX_CFG_PRT)
                break;

              if (gpsc_state == GPSC_RESTART_WAIT)
                gpsc_change_state(GPSC_CONFIG_DONE, GPSW_PIPE_RESTART);
              else
                gpsc_change_state(GPSC_CONFIG_CHK, GPSW_BOOT);
              rtn = TRUE;
              break;

            case GPSC_CONFIG_MSG_ACK:
              ubx_ack = (void *) rx_msg;
              if (ubx_ack->class    != UBX_CLASS_ACK    ||
                  ubx_ack->id       != UBX_ACK_ACK      ||
                  ubx_ack->len      != 2                ||
                  ubx_ack->ackClass != UBX_CLASS_CFG    ||
                  ubx_ack->ackId    != UBX_CFG_MSG)
                break;

              gpsc_change_state(GPSC_CONFIG_MSG, GPSW_BOOT);
              rtn = TRUE;
              break;

            case GPSC_CONFIG_SAVE_ACK:
              ubx_ack = (void *) rx_msg;
              if (ubx_ack->class    != UBX_CLASS_ACK    ||
                  ubx_ack->id       != UBX_ACK_ACK      ||
                  ubx_ack->len      != 2                ||
                  ubx_ack->ackClass != UBX_CLASS_CFG    ||
                  ubx_ack->ackId    != UBX_CFG_CFG)
                break;

              gpsc_change_state(GPSC_CONFIG_DONE, GPSW_BOOT);
              rtn = TRUE;
              break;

            case GPSC_VER_WAIT:
              ubx_hdr = (void *) rx_msg;
              if (ubx_hdr->class   != UBX_CLASS_MON    ||
                  ubx_hdr->id      != UBX_MON_VER      ||
                  ubx_hdr->len     <  40)
                break;
              gpsc_change_state(GPSC_VER_DONE, GPSW_BOOT);
              rtn = TRUE;
              break;

          }
        } while (0);
        call MsgBuf.msg_release();
      }
    }
    return rtn;
  }


  void ubx_send_msg(uint8_t *msg, uint16_t len) {
    uint8_t data;

    call GPSLog.collect(msg, len, GPS_DIR_TX, NULL);
    call HW.spi_put(0xff);
    while (len) {
      data = call HW.spi_getput(*msg++);
      len--;
      process_byte(data);
    }
    data = call HW.spi_get();
    process_byte(data);
  }


  /*
   * ubx_get_msgs: snag one or more messages from the pipe.
   *     terminates when we either timeout (duration) or a state change
   *     has occured.  (see process_byte()).
   *
   * input:     duration, max duration to look
   *            use_txrdy, TRUE if use hw txrdy line.
   * output:    indirect (see below).
   *
   * if use_txrdy is set, we will use TXRDY as the indicator that bytes are
   * in the pipe.  Otherwise, we will loop pulling bytes from the pipe (will
   * be idle bytes if empty).
   *
   * On entry we will loop looking for the start of a packet, we will look
   * for a maximum of "duration".
   *
   * Once we have seen non-idle packet data, we will pull bytes and feed them
   * to the protocol engine via "process_byte()".  If packet processing causes
   * a state change (see process_byte()), we will stop collecting messages.
   *
   * If no state change has occured, we will collect messages for a maximum
   * of "duration".
   */

  void ubx_get_msgs(uint32_t duration, bool use_txrdy) {
    uint8_t  data;
    uint32_t t0, t1;
    uint32_t dwn_cnt;

    dwn_cnt = 8;
    t0 = call Platform.usecsRaw();
    if (use_txrdy) {
      while (TRUE) {
        t1 = call Platform.usecsRaw();
        if ((t1 - t0) > duration)
          return;
        if (call HW.gps_txrdy())
          break;
      }
    }

    call HW.spi_put(0xff);
    while (TRUE) {
      t1 = call Platform.usecsRaw();
      if ((t1 - t0) > duration)
        break;
      data = call HW.spi_getput(0xff);

      /* if process_byte returns TRUE there was a state change */
      if (process_byte(data))
        break;
      if (use_txrdy) {
        if (call HW.gps_txrdy()) {
          dwn_cnt = 8;
          continue;
        }
        if (--dwn_cnt == 0)
          break;
      }
    }

    data = call HW.spi_get();
    process_byte(data);
  }


  void ubx_clean_pipe(uint32_t max_duration) {
    uint8_t  data;
    uint32_t t0, t1;
    uint32_t term_left;

    term_left = 8;
    call HW.spi_put(0xff);
    t0 = call Platform.usecsRaw();
    while (TRUE) {
      t1 = call Platform.usecsRaw();
      if ((t1 - t0) > max_duration)
        break;
      data = call HW.spi_getput(0xff);
      process_byte(data);
      if (data == 0xff) {
        if (--term_left == 0)
          break;
      } else
        term_left = 8;
    }
    data = call HW.spi_get();
    process_byte(data);

    /*
     * We don't handle the corner case of seeing a non-ff
     * byte after the pipe has been cleaned.  Doesn't hurt anything
     */
  }


  void configure_msgs() {
    uint8_t       *ncp;
    ubx_cfg_msg_t  cfgmsg;
    uint16_t       chk;

    ncp = &ubx_nav_cfgs[0];
    cfgmsg.sync1 = UBX_SYNC1;
    cfgmsg.sync2 = UBX_SYNC2;
    cfgmsg.class = UBX_CLASS_CFG;
    cfgmsg.id    = UBX_CFG_MSG;
    cfgmsg.len   = 3;
    cfgmsg.msgClass = UBX_CLASS_NAV;
    while (*ncp) {
      gpsc_change_state(GPSC_CONFIG_MSG, GPSW_BOOT);
      cfgmsg.msgId = *ncp;
      cfgmsg.rate  = 1;
      chk = call ubxProto.fletcher8((void *) &cfgmsg.class, cfgmsg.len + UBX_CHKSUM_ADJUST);
      cfgmsg.chkA = chk >> 8;
      cfgmsg.chkB = chk & 0xff;
      ubx_send_msg((void *) &cfgmsg, sizeof(cfgmsg));
      gpsc_change_state(GPSC_CONFIG_MSG_ACK, GPSW_BOOT);
      ubx_get_msgs(104858, TRUE);
      if (gpsc_state != GPSC_CONFIG_MSG)
        gps_panic(22, 0, 0);
      ncp++;
    }
#ifdef notdef
    cfgmsg.msgClass = UBX_CLASS_TIM;
    cfgmsg.msgId    = UBX_TIM_TP;
    cfgmsg.rate     = 1;
    chk = call ubxProto.fletcher8((void *) &cfgmsg.class, cfgmsg.len + UBX_CHKSUM_ADJUST);
    cfgmsg.chkA = chk >> 8;
    cfgmsg.chkB = chk & 0xff;
    ubx_send_msg((void *) &cfgmsg, sizeof(cfgmsg));
    gpsc_change_state(GPSC_CONFIG_MSG_ACK, GPSW_BOOT);
    ubx_get_msgs(104858, TRUE);
    if (gpsc_state != GPSC_CONFIG_MSG)
      gps_panic(23, 0, 0);
#endif

    ubx_send_msg((void *) ubx_cfg_cfg_save, sizeof(ubx_cfg_cfg_save));
    gpsc_change_state(GPSC_CONFIG_SAVE_ACK, GPSW_BOOT);
    ubx_get_msgs(104858, TRUE);
    if (gpsc_state != GPSC_CONFIG_DONE)
      gps_panic(27, 0, 0);
  }


  /*
   * the spi pipe has stall.
   *
   * we free it up by sending the spi port reconfiguration command.
   */
  event void HW.spi_pipe_stall() {
    uint32_t      t1, t5;
    gpsc_state_t  prev_state;

    call CollectEvent.logEvent(DT_EVENT_GPS_PIPE_STALL, gpsc_state, 0, 0, 0);
    prev_state = gpsc_state;
    t5 = call Platform.usecsRaw();

    while (TRUE) {
      t1 = call Platform.usecsRaw();
      if ((t1 - t5) > 524288)
        gps_panic(27, t1 - t5, 0);

      gpsc_change_state(GPSC_RESTART_WAIT, GPSW_PIPE_RESTART);

      /* first hold CS up for at least 1 ms, then reassert */
      call HW.gps_clr_cs_delay();
      call HW.gps_set_cs();
      ubx_send_msg((void *) ubx_cfg_prt_spi_txrdy, sizeof(ubx_cfg_prt_spi_txrdy));

      call HW.gps_clr_cs_delay();
      call HW.gps_set_cs();
      ubx_get_msgs(104858, FALSE);

      if (gpsc_state == GPSC_CONFIG_DONE)
        break;
    };

    gpsc_change_state(prev_state, GPSW_PIPE_RESTART);
    call HW.spi_pipe_restart();
  }


  /*
   * Standalone initializer for Ubx M8 based gps chips.
   *
   * This is Boot up.  we don't know what state the ublox chip is in.  It
   * is possible that the SPI pipeline is out of sync.  We deassert CS
   * for the required 1ms and then reassert.
   *
   * o force TxRdy enable
   * o verify TxRdy took by doing a port config poll
   * o enable any UBX messages we need.
   * o get HW and SW verions to stash
   * o put GPS into sleep.
   *
   * The low level GPS bootstrap gets run once per boot.
   */

  event void Boot.booted() {
    uint32_t t0, t1;

    if (gpsc_state != GPSC_OFF)
      gps_panic(24, gpsc_state, 0);

//    WIGGLE_EXC; WIGGLE_EXC; WIGGLE_EXC; WIGGLE_TELL; WIGGLE_TELL; WIGGLE_TELL;
    t_gps_boot_start = call LocalTime.get();

    /* initialize and disable the interrupt */
    gpsc_change_state(GPSC_CONFIG_BOOT, GPSW_BOOT);
    call CollectEvent.logEvent(DT_EVENT_GPS_BOOT, t_gps_boot_start, 0, 0, 0);
//    if (!call HW.gps_powered())
//      call HW.gps_pwr_on();
    call HW.gps_pwr_on();
#ifdef notdef
    call HW.gps_set_reset();

    /* hold reset for about 10 ms */
    t0 = call Platform.usecsRaw();
    do {
      t1 = call Platform.usecsRaw();
    } while ((t1 - t0) < 11000);
    call HW.gps_clr_reset();

    /* let it stew for about 100 ms */
    t0 = call Platform.usecsRaw();
    do {
      t1 = call Platform.usecsRaw();
    } while ((t1 - t0) < 104858);
#endif

    gpsc_count = 1;
    t0 = call Platform.usecsRaw();
    while (TRUE) {
      t1 = call Platform.usecsRaw();
      if (t1 - t0 > 524288) {
        WIGGLE_TELL; WIGGLE_TELL; WIGGLE_TELL; WIGGLE_EXC; WIGGLE_EXC; WIGGLE_EXC;
        gps_panic(25, gpsc_state, t1 - t0);
      }

      call HW.gps_clr_cs_delay();
      call HW.gps_set_cs();

      /*
       * We just booted.  We don't know the configuration of the GPS chip.
       * Send the port configuraton first to enable TXRDY.
       *
       * waiting for the TXRDY_ACK.
       *
       * CONFIG_BOOT -> CONFIG_TXRDY_ACK -> CONFIG_CHK
       *
       * After sending the CFG_PRT, the ublox will reset the SPI pipeline.
       * When the pipe is back up, the ublox will send an appropriate ACK.
       * This ACK will cause the state change.
       */
      gpsc_change_state(GPSC_CONFIG_TXRDY_ACK, GPSW_BOOT);
      call ubxProto.restart();
      ubx_send_msg((void *) ubx_cfg_prt_spi_txrdy, sizeof(ubx_cfg_prt_spi_txrdy));
      WIGGLE_EXC;

      /*
       * note that we could be receiving a packet from the ubx chip.  But the
       * cfg_prt packet we just sent will reset the spi pipeline.   If we don't
       * restart the protocol handler, it is possible that the ack we are
       * looking for will get eaten (added to a potential packet we thought we
       * were receiving).
       */
      call ubxProto.restart();
      ubx_get_msgs(104858, FALSE);
      WIGGLE_EXC;

      /*
       * At this point we should have a clean pipe.  We don't know if the ublox
       * chip ack'd the cfg/prt or if we saw the ack.  But it doesn't matter.
       * We simply force GPSC_CONFIG_CHK, issue cfg/prt (poll), and see if we
       * get something reasonable (ie. txrdy set properly).
       *
       * sent reconfig to turn on TXRDY (nmea off, ubx on).  See if it took.
       * We ignore whether the TXRDY ack occured.  Simply send the poll to
       * verify if the configuration command too.
       */
      gpsc_change_state(GPSC_CONFIG_CHK, GPSW_BOOT);
      ubx_send_msg((void *) ubx_cfg_prt_poll_spi,  sizeof(ubx_cfg_prt_poll_spi));
      WIGGLE_EXC;
      ubx_get_msgs(104858, FALSE);
      WIGGLE_EXC;

      /*
       *               CONFIG_TXRDY_ACK     send timed out
       * CONFIG_CHK -> CONFIG_SET_TXRDY     wrong setting, try again
       * CONFIG_CHK -> CONFIG_DONE          proceed.
       */
      if (gpsc_state == GPSC_CONFIG_DONE)
        break;
      gpsc_count++;
    };

    if (gpsc_count > 1)
      gps_warn(13, gpsc_count, 0);

    ubx_clean_pipe(104858);
    WIGGLE_EXC;
    configure_msgs();
    WIGGLE_EXC;

    gpsc_change_state(GPSC_VER_WAIT, GPSW_BOOT);
    ubx_clean_pipe(104858);
    ubx_send_msg((void *) ubx_mon_hw_poll, sizeof(ubx_mon_hw_poll));
    t0 = call Platform.usecsRaw();
    gpsc_count = 1;
    while (TRUE) {
      t1 = call Platform.usecsRaw();
      if (t1 - t0 > 104858)
        gps_panic(26, gpsc_state, 0);
      ubx_send_msg((void *) ubx_mon_ver_poll, sizeof(ubx_mon_ver_poll));
      ubx_get_msgs(104858, TRUE);
      if (gpsc_state == GPSC_VER_DONE)
        break;
      gpsc_count++;
    }

    if (gpsc_count > 1)
      gps_warn(14, gpsc_count, 0);

    ubx_clean_pipe(104858);

    /*
     * We leave the gps up.  Hand off to the rest of the system bootstrap.
     * At the end of the system bootstrap the GPSMonitor gets woken up.
     * It will run a normal wake up cycle, then will start cycling the GPS.
     */
    t_gps_boot_end = call LocalTime.get();
    t_gps_boot_delta = t_gps_boot_end - t_gps_boot_start;

    call CollectEvent.logEvent(DT_EVENT_GPS_BOOT_TIME, t_gps_boot_end,
                               t_gps_boot_delta, 0, 0);
    gpsc_change_state(GPSC_ON, GPSW_BOOT);
    call HW.gps_txrdy_int_enable(19);
    signal Booted.booted();
  }


  /*
   * gps_hibernate: put the ublox into standby (backup)
   *
   * The ubx chip is put into backup by doing the following steps.
   *
   * o drop CSN (assert, probably already asserted)
   * o send rxm/pmreq(backup, duration 0)
   * o raise CS (deassert)
   * o reset ubxProto to abort any packet in progress
   *
   * Approximately 5 ms (observed) after the end of rmx/pmreq and
   * the deassertion of CS, the ublox will undrive its pins including
   * TxRdy.  There is an internal pull up on TxRdy so it looks asserted.
   * We disable the TxRdy interrupt.  We wait for STANDBY_TO and
   * verify that TxRdy has gone high.
   *
   * The STANDBY_TO timing is handled by GPSControl.standby().
   */
  void gps_hibernate() {
    uint32_t txrdy;

    txrdy = call HW.gps_txrdy();
    call HW.gps_txrdy_int_disable();
    call CollectEvent.logEvent(DT_EVENT_GPS_STANDBY, txrdy, 0, 0, 0);
    call HW.gps_set_cs();
    ubx_send_msg((void *) ubx_rxm_pmreq_backup_0, sizeof(ubx_rxm_pmreq_backup_0));
    call HW.gps_clr_cs();
    call ubxProto.restart();
  }


  /*
   * GPSControl.standby: Put the GPS chip into standby.
   */
  command error_t GPSControl.standby() {
    if (!gpsc_state || gpsc_state > GPSC_ON_RX_TX)
      gps_panic(27, gpsc_state, 0);
    call HW.gps_txrdy_int_disable();
    gpsc_count = 10;                    /* try 10 times */
    gpsc_change_state(GPSC_STANDBY_WAIT, GPSW_STANDBY);
    call GPSTxTimer.stop();
    call GPSRxTimer.stop();
    gps_hibernate();
    call GPSTxTimer.startOneShot(DT_GPS_STANDBY_TO);
    return SUCCESS;
  }


  /*
   * gps_wakeup: bring the ublox out of standby, wake it up.
   *
   * We wake the gps chip by dropping chip select (assert).  This starts
   * the process.  The chip takes some time (68ms observed) because it has
   * to wake the on board ARM and reconfigure its pins.
   *
   * We wait DT_GPS_WAKE_WAIT and then turn the txrdy_int_enable back on.
   * Normally we could just turn on the txrdy_int but this process also
   * checks for txrdy assertion and if set invokes the driver_task, which
   * then sees a pipeline stall (the ARM hasn't fired the SPI up yet).
   *
   * So we need to wait.
   */
  void gps_wakeup() {
    uint32_t txrdy;

    txrdy = call HW.gps_txrdy();
    call CollectEvent.logEvent(DT_EVENT_GPS_WAKEUP, txrdy, 0, 0, 0);
    call HW.gps_set_cs();
  }


  command error_t GPSControl.wakeup() {
    if (gpsc_state != GPSC_STANDBY)
        gps_panic(28, gpsc_state, 0);
    gpsc_change_state(GPSC_WAKE_WAIT, GPSW_WAKEUP);
    gps_wakeup();
    call GPSTxTimer.startOneShot(DT_GPS_WAKE_DELAY);
    return SUCCESS;
  }


  command void GPSControl.hibernate() {
    gps_hibernate();
  }


  command void GPSControl.wake() {
    gps_wakeup();
  }


        event void Collect.collectBooted() { }
  async event void Panic.hook() { }

  default event void GPSControl.standbyDone()   { };
  default event void GPSControl.gps_boot_fail() { };
  default event void GPSControl.gps_booted()    { };
  default event void GPSControl.gps_shutdown()  { };
}
