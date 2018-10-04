/*
 * Copyright (c) 2017-2018 Eric B. Decker
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
 */

/*
 * The GPSmonitor sits on top of the GPS stack and handles interactions.
 * When first booting we need to wait for SSW to be up before starting
 * up.  We log to the stream.
 *
 * First, it receives any packets coming from the GPS chip.  Note all
 * multibyte datums in the GPS packets are big endian.  We are little
 * endian so must compensate.
 *
 * *** State Machine Description (GMS_), Gps Monitor State
 *
 * OFF          powered completely off
 *
 * FAIL         we gave up
 *
 * BOOTING      first boot after reboot, establish comm
 *
 * CONFIG       configuation messages, currently only swver
 *
 * COMM_CHECK   Make sure we can communicate with the gps.  Control
 *              entry to MPM (Sleeping, IDLE) or COLLECT (awake,
 *              CYCLE, MPM_COLLECT).
 *
 * COLLECT      collecting fixes (awake, CYCLE, MPM_COLLECT).  grabbing
 *              almanac, ephemeri, time calibration.
 *
 * MPM_WAIT     mpm has been requested.  looking for response.
 *
 * MPM_RESTART  mpm has responsed with an error.  The gps will shutdown and
 *              we will restart.
 *
 * MPM          running MPM cycles.
 *
 * STANDBY      in Standby
 *
 *********
 *
 * Major States
 *
 * IDLE         sleeping, MPM cycles
 * CYCLE        simple fix cycle
 * MPM_COLLECT  collecting fixes to help MPM heal.
 * SATS_COLLECT collecting fixes for almanac and ephemis collection
 * TIME_COLLECT collecting fixes when doing time syncronization
 */


#include <overwatch.h>
#include <TagnetTLV.h>
#include <sirf_msg.h>
#include <mm_byteswap.h>
#include <sirf_driver.h>
#include <gps_mon.h>
#include <rtctime.h>

#ifndef PANIC_GPS
enum {
  __pcode_gps = unique(UQ_PANIC_SUBSYS)
};

#define PANIC_GPS __pcode_gps
#endif


#define GPS_MON_SWVER_TO            1024
#define GPS_MON_SHORT_COMM_TO       2048
#define GPS_MON_LONG_COMM_TO        8192
#define GPS_MON_MPM_RSP_TO          2048
#define GPS_MON_MPM_RESTART_WAIT    2048
#define GPS_MON_COLLECT_DEADMAN     16384

// 30 secs
#define GPS_MON_CYCLE_TIME          ( 1 * 30 * 1024)
#define GPS_MON_MPM_COLLECT_TIME    ( 2 * 60 * 1024)

// 2 hours
#define GPS_MON_SATS_STARTUP_TIME   ( 2 * 60 * 60 * 1024)

// 4 hours
#define GPS_MON_SLEEP               ( 4 * 60 * 60 * 1024)

/*
 * mpm_rsp_to   timeout for listening for mpm rsp after
 *              mpm req sent.  If timeout assume off.
 *
 * mpm_restart_wait  restart window after seeing an mpm error.
 *              time limit after seeing the error.  should see
 *              an ots_no first but in case we don't this
 *              timer will catch it.
 *
 * collect_deadman  backstop in case COLLECT doesn't see any
 *              messages.  Shouldn't happen.
 *
 * mpm_collect_time following an mpm error we go into collect
 *              to let mpm stablize.
 *
 * cycle_time   time from wake up (MPM pulse) to next sleep (MPM).
 *              Window allowed for normal cycle, looking for locks.
 *              (uses MajorTimer)
 *
 * mon_sleep    when in MPM, how long to stay asleep before next fix.
 */

/*
 * Internal Storage types.
 *
 * We hang onto various data from the GPS persistently.
 * These types define what these structures look like.
 * They are instantated in the implementation block.
 */

/* from MID 2, NAV_DATA */
typedef struct {
  rtctime_t rt;                         /* rtctime - last seen */
  uint32_t tow;                         /* reported time of week */
  int32_t  x;                           /* ECEF X */
  int32_t  y;                           /* ECEF Y */
  int32_t  z;                           /* ECEF Z */
  uint16_t week;                        /* 10 bit week, broken */
  uint8_t  mode1;                       /* position mode of last fix  */
  uint8_t  hdop;                        /* horz dop * 5               */
  uint8_t  nsats;                       /* number of sats in solution */
} gps_xyz_t;


/* from MID 7, clock status */
typedef struct {
  rtctime_t rt;                         /* rtctime - last seen */
  uint32_t drift;
  uint32_t bias;
  uint32_t tow;                         /* reported time of week */
  uint16_t week_x;                      /* extended week */
  uint8_t  nsats;
} gps_clock_t;


/* from MID 41, geodetic data */
typedef struct {
  rtctime_t rt;                         /* rtctime - last seen */
  uint32_t tow;                         /* time of week, * 1000 */
  uint16_t week_x;                      /* extended week */
  uint8_t  nsats;                       /* how many sats in solution */
  uint8_t  additional_mode;
  int32_t  lat;                         /*  +N * 10^7 */
  int32_t  lon;                         /*  +E * 10^7 */
  uint32_t sat_mask;                    /* which sats used in solution */
  uint16_t nav_valid;                   /* bit mask */
  uint16_t nav_type;                    /* bit mask */
  uint32_t ehpe;                        /* m * 100 */
  uint32_t evpe;                        /* m * 100 */
  int32_t  alt_ell;                     /* altitude ellipsoid m * 100 */
  int32_t  alt_msl;                     /* altitude msl m * 100 */
  uint16_t sog;                         /* m/s * 100 */
  uint16_t cog;                         /* deg cw from N_t * 100 */
  uint8_t  hdop;
} gps_geo_t;


/* from mid 52, 1pps data */
typedef struct {
  rtctime_t rt;                         /* rtctime - last seen */
  uint32_t mark_us;                     /* when mark was seen in usecs */
  uint16_t year;
  uint16_t utcintoff;
  uint32_t utcfracoff;
  uint8_t  hr;
  uint8_t  min;
  uint8_t  sec;
  uint8_t  day;
  uint8_t  mo;
  uint8_t  status;
} gps_1pps_t;


/* extracted from MID 41, Geodetic */
typedef struct {
  rtctime_t rt;                         /* rtctime - last seen */
  uint32_t tow;                         /* seconds x 1e3 */
  uint16_t week_x;
  uint16_t utc_year;
  uint8_t  utc_month;
  uint8_t  utc_day;
  uint8_t  utc_hour;
  uint8_t  utc_min;
  uint16_t utc_ms;			/* x 1e3 (millisecs) */
  uint8_t  nsats;
} gps_time_t;


typedef struct {
  const uint8_t *msg;
  uint32_t       len;
} gps_canned_t;


#define GMCB_MAJIK 0xAF52FFFF

typedef struct {
  uint32_t           majik_a;
  gpsm_state_t       minor_state;           /* monitor basic state - minor */
  gpsm_major_state_t major_state;           /* monitor major state */
  uint16_t           retry_count;
  uint16_t           msg_count;             /* used to tell if we are seeing msgs */
  bool               lock_seen;             /* lock seen in current cycle */
  uint32_t           majik_b;
} gps_monitor_control_t;

module GPSmonitorP {
  provides {
    interface TagnetAdapter<tagnet_gps_xyz_t> as InfoSensGpsXyz;
    interface TagnetAdapter<tagnet_gps_cmd_t> as InfoSensGpsCmd;
  } uses {
    interface Boot;                           /* in boot */
    interface GPSControl;
    interface GPSTransmit;
    interface GPSReceive;
    interface PwrReg as GPSPwr;

    interface Collect;
    interface CollectEvent;
    interface Rtc;

    interface Timer<TMilli> as MinorTimer;
    interface Timer<TMilli> as MajorTimer;
    interface Panic;
    interface OverWatch;
    interface TagnetMonitor;
  }
}
implementation {
  gps_monitor_control_t gmcb;           /* gps monitor control block */

  uint32_t     cycle_start, cycle_count, cycle_sum;
  uint32_t     last_nsats_seen, last_nsats_count;

#define LAST_NSATS_COUNT_INIT 10

  gps_xyz_t  m_xyz;
  gps_geo_t  m_geo;
  gps_time_t m_time;
  gps_1pps_t m_pps;

  void major_event(mon_event_t ev);

  void gps_warn(uint8_t where, parg_t p, parg_t p1) {
    call Panic.warn(PANIC_GPS, where, p, p1, 0, 0);
  }

  void gps_panic(uint8_t where, parg_t p, parg_t p1) {
    call Panic.panic(PANIC_GPS, where, p, p1, 0, 0);
  }


  void verify_gmcb() {
    if (gmcb.majik_a != GMCB_MAJIK || gmcb.majik_a != GMCB_MAJIK)
      gps_panic(102, (parg_t) &gmcb, 0);
    if (gmcb.minor_state > GMS_MAX || gmcb.major_state > GMS_MAJOR_MAX)
      gps_panic(103, gmcb.minor_state, gmcb.major_state);
  }

  void major_change_state(gpsm_major_state_t new_state, mon_event_t ev) {
    verify_gmcb();
    call CollectEvent.logEvent(DT_EVENT_GPS_MON_MAJOR, gmcb.major_state,
                               new_state, ev, 0);
    gmcb.major_state = new_state;
    last_nsats_count = 0;
  }


  void minor_change_state(gpsm_state_t new_state, mon_event_t ev) {
    call CollectEvent.logEvent(DT_EVENT_GPS_MON_MINOR, gmcb.minor_state,
                               new_state, ev, 0);
    gmcb.minor_state = new_state;
    last_nsats_count = 0;
  }


  void mon_enter_comm_check(mon_event_t ev) {
    gmcb.retry_count = 0;
    minor_change_state(GMS_COMM_CHECK, ev);
    call MinorTimer.startOneShot(GPS_MON_SHORT_COMM_TO);
  }


  void mon_pulse_comm_check(mon_event_t ev) {
    call GPSControl.pulseOnOff();
    mon_enter_comm_check(ev);
  }


  /*
   * We are being told the system has come up.
   * make sure we can communicate with the GPS and that it is
   * the proper state.
   *
   * GPSControl.turnOn will always respond either with a
   * GPSControl.gps_booted or gps_boot_fail signal.
   *
   * No need for a timer here.
   */
  event void Boot.booted() {
    gmcb.retry_count = 0;               /* haven't retried yet */
    gmcb.majik_a = gmcb.majik_b = GMCB_MAJIK;
    major_change_state(GMS_MAJOR_IDLE, MON_EV_BOOT);
    minor_change_state(GMS_BOOTING,    MON_EV_BOOT);
    call CollectEvent.logEvent(DT_EVENT_GPS_BOOT, gmcb.minor_state,
                               gmcb.retry_count, 0, 0);
    call GPSControl.turnOn();
  }


  event void GPSControl.gps_booted() {
    switch (gmcb.minor_state) {
      default:
        gps_panic(1, gmcb.minor_state, 0);
        return;
      case GMS_OFF:                     /* coming out of power off */
      case GMS_BOOTING:                 /* or 1st boot */
        gmcb.msg_count   = 0;
        gmcb.retry_count = 0;
        gmcb.lock_seen   = FALSE;
        minor_change_state(GMS_CONFIG, MON_EV_STARTUP);
        call GPSControl.logStats();
        call GPSTransmit.send((void *) sirf_swver, sizeof(sirf_swver));
        cycle_start= call MajorTimer.getNow();
        call MinorTimer.startOneShot(GPS_MON_SWVER_TO);
        return;
    }
  }


  /*
   * event gps_boot_fail():  didn't work try again.
   *
   * the gps driver does a gps_reset prior to signalling.
   *
   * first time, just do a normal turn on.  (already tried).
   * second time, just try again, already reset.
   * third time, bounce power.
   */
  event void GPSControl.gps_boot_fail() {
    switch (gmcb.minor_state) {
      default:
        gps_panic(2, gmcb.minor_state, 0);
        return;
      case GMS_OFF:
      case GMS_BOOTING:
        gmcb.retry_count++;
        switch (gmcb.retry_count) {
          default:
            /* subsystem fail */
            gps_panic(3, gmcb.minor_state, gmcb.retry_count);
            call MinorTimer.stop();
            call MajorTimer.stop();
            call GPSControl.logStats();
            minor_change_state(GMS_FAIL, MON_EV_FAIL);
            return;

          case 1:
            /* first time didn't work, hit it with a reset and try again. */
            call CollectEvent.logEvent(DT_EVENT_GPS_BOOT, gmcb.minor_state,
                                       gmcb.retry_count, 0, 0);
            call GPSControl.logStats();
            call GPSControl.reset();
            call GPSControl.turnOn();
            return;

          case 2:
            call CollectEvent.logEvent(DT_EVENT_GPS_BOOT, gmcb.minor_state,
                                       gmcb.retry_count, 0, 0);
            call GPSControl.logStats();
            call GPSControl.powerOff();
            call GPSControl.powerOn();
            call GPSControl.turnOn();
            return;
        }
    }
  }


  command bool InfoSensGpsXyz.get_value(tagnet_gps_xyz_t *t, uint32_t *l) {
    if (!t || !l)
      gps_panic(0, 0, 0);
    t->gps_x = m_xyz.x;
    t->gps_y = m_xyz.y;
    t->gps_z = m_xyz.z;
    *l = TN_GPS_XYZ_LEN;
    return 1;
  }

  /* also in tagcore/gps_mon.py  */
  const gps_canned_t canned_msgs[] = {
    { sirf_peek_0,              sizeof(sirf_peek_0)        },   /* 0 */
    { sirf_swver,               sizeof(sirf_swver)         },   /* 1 */
    { sirf_factory_reset,       sizeof(sirf_factory_reset) },   /* 2 */
    { sirf_factory_clear,       sizeof(sirf_factory_clear) },   /* 3 */
  };

#define MAX_CANNED 3
#define MAX_RAW_TX 64

  /*
   * The network stack pass in a buffer that has the data we want to send
   * however, we don't own that.  So if we are transmitting the data
   * out we need to copy it to a buffer we own so it doesn't get overwritten.
   */
  bool    raw_tx_busy;
  uint8_t raw_tx_buf[MAX_RAW_TX];

  command bool InfoSensGpsXyz.set_value(tagnet_gps_xyz_t *t, uint32_t *l) {
    if (!t || !l)
      gps_panic(0, 0, 0);               /* no return */
    return FALSE;
  }

  /*
   * GPS CMD state.
   *
   * gps_cmd_count is the last cmd packet we have seen.  We won't accept
   * the next next packet unless it is flagged with the proper iota which
   * needs to be gps_cmd_count + 1.
   *
   * The current cmd_count can be obtained by asking InfoSensGpsCmd.get_value
   * which will return gps_cmd_count (ie. the last cmd we saw)
   */
  uint32_t   gps_cmd_count;             /* inits to 0 */

  command bool InfoSensGpsCmd.get_value(tagnet_gps_cmd_t *db, uint32_t *lenp) {
    if (!db || !lenp)
      gps_panic(0, 0, 0);               /* no return */
    *lenp = 0;                          /* no actual content */
    db->iota  = gps_cmd_count;          /* return current state */
    db->count = gps_cmd_count;          /* seq no. for last cmd we've seen */
    db->error  = SUCCESS;               /* default */
    if (db->action == FILE_GET_ATTR)
      return TRUE;
    return FALSE;
  }


  void copy_data(uint8_t *dst, uint8_t *src, uint32_t l) {
    while (l) {
      *dst++ = *src++;
      l--;
    }
  }

  command bool InfoSensGpsCmd.set_value(tagnet_gps_cmd_t *db, uint32_t *lenp) {
    gps_raw_tx_t *gp;
    error_t err;
    bool    awake;
    uint32_t l;

    /* too weird, too small, bitch */
    if (!db || !lenp)
      gps_panic(0, 0, 0);               /* no return */

    db->error = SUCCESS;
    if (!*lenp)
      return TRUE;
    if (db->action != FILE_SET_DATA) {
      *lenp = 0;                        /* don't send anything back */
      return FALSE;                     /* ignore */
    }

    if (db->iota != gps_cmd_count + 1) {
      /*
       * if it isn't what we expect, tell the other side we are happy
       * but don't do anything.
       */
      db->iota  = gps_cmd_count;        /* but tell which one we are actually on. */
      db->count = gps_cmd_count;
      db->error = EINVAL;
      *lenp = 0;
      return TRUE;
    }

    gp = (void *) db->block;
    call CollectEvent.logEvent(DT_EVENT_GPS_CMD, gp->cmd,
                               0, 0, call GPSControl.awake());
    switch (gp->cmd) {
      default:
      case GDC_NOP:
        break;

      case GDC_TURNON:
        err = call GPSControl.turnOn();
        call CollectEvent.logEvent(DT_EVENT_GPS_CMD, gp->cmd, err, 1,
                                   call GPSControl.awake());
        break;

      case GDC_TURNOFF:
        err = call GPSControl.turnOff();
        call CollectEvent.logEvent(DT_EVENT_GPS_CMD, gp->cmd, err, 1,
                                   call GPSControl.awake());
        break;

      case GDC_STANDBY:
        err = call GPSControl.standby();
        call CollectEvent.logEvent(DT_EVENT_GPS_CMD, gp->cmd, err, 1,
                                   call GPSControl.awake());
        break;

      case GDC_POWER_ON:
        call GPSControl.powerOn();
        break;

      case GDC_POWER_OFF:
        call GPSControl.powerOff();
        break;

      case GDC_CYCLE:
        major_event(MON_EV_CYCLE);
        break;

      case GDC_STATE:
        major_event(MON_EV_STATE_CHK);
        break;

      case GDC_MON_GO_HOME:
        call TagnetMonitor.setHome();
        break;

      case GDC_MON_GO_NEAR:
        call TagnetMonitor.setNear();
        break;

      case GDC_MON_GO_LOST:
        call TagnetMonitor.setLost();
        break;

      case GDC_AWAKE_STATUS:
        call CollectEvent.logEvent(DT_EVENT_GPS_AWAKE_S, 999, 0, 0,
                                   call GPSControl.awake());
        break;

      case GDC_MPM:
        awake = call GPSControl.awake();
        err   = call GPSTransmit.send((void *) sirf_go_mpm_0, sizeof(sirf_go_mpm_0));
        call CollectEvent.logEvent(DT_EVENT_GPS_MPM, 999, err, 0, awake);
        break;

      case GDC_PULSE:
        call CollectEvent.logEvent(DT_EVENT_GPS_PULSE, 999, 0, 0,
                                   call GPSControl.awake());
        call GPSControl.pulseOnOff();
        break;

      case GDC_RESET:
        call GPSControl.reset();
        break;

      case GDC_RAW_TX:
        l = *lenp - 1;                  /* grab the length of the message */
        awake = call GPSControl.awake();
        do {
          if (l > MAX_RAW_TX) {           /* bail if too big */
            err = ESIZE;
            break;
          }
          if (raw_tx_busy) {
            err = EBUSY;
            break;
          }
          /* raw_tx_buf <- gp->data */
          copy_data(raw_tx_buf, gp->data, l);
          err   = call GPSTransmit.send(raw_tx_buf, *lenp - 1);
        } while (0);
        call CollectEvent.logEvent(DT_EVENT_GPS_RAW_TX, 999, err, l, awake);
        break;

      case GDC_HIBERNATE:
        call GPSControl.hibernate();
        break;

      case GDC_WAKE:
        call GPSControl.wake();
        break;

      case GDC_CANNED:
        l   = gp->data[0];              /* grab the msg code */
        awake = call GPSControl.awake();
        do {
          if (l > MAX_CANNED) {
            err = EINVAL;
            break;
          }
          err   = call GPSTransmit.send((void *) canned_msgs[l].msg,
                                        canned_msgs[l].len);
        } while (0);
        call CollectEvent.logEvent(DT_EVENT_GPS_CANNED, l, err, l, awake);
        break;

        /*********************************************************************
         * Set overwatch logging_flags,
         *
         * {SET,CLR}_LOG_FLAG take a single byte number that is the enum of
         * the flag to set or clear.
         *
         * {SET,CLR}_LOGGING takes a 4 byte little endian number that is used
         * to clear or set the logging_flags.
         *
         * FORCE jam loads the logging_flags.
         */
      case GDC_SET_LOG_FLAG:
        l = gp->data[0];                /* get the flag to set */
        call OverWatch.setLoggingFlag(l);
        break;

      case GDC_CLR_LOG_FLAG:
        l = gp->data[0];                /* get the flag to set */
        call OverWatch.clrLoggingFlag(l);
        break;

      case GDC_SET_LOGGING:
        /* first grab the 32 bit number that is the mask */
        l = 0;
        copy_data((void *) &l, gp->data, *lenp - 1);
        call OverWatch.setLoggingFlagsM(l);
        break;

      case GDC_CLR_LOGGING:
        l = 0;
        copy_data((void *) &l, gp->data, *lenp - 1);
        call OverWatch.clrLoggingFlagsM(l);
        break;

      case GDC_FORCE_LOGGING:
        l = 0;
        copy_data((void *) &l, gp->data, *lenp - 1);
        call OverWatch.forceLoggingFlags(l);
        break;


      case GDC_LOW:
        break;

      case GDC_SLEEP:
        call OverWatch.halt_and_CF();
        break;

      case GDC_PANIC:
        gps_panic(99, 0, 0);
        break;

      case GDC_REBOOT:
        call OverWatch.flush_boot(call OverWatch.getBootMode(),
                                  ORR_USER_REQUEST);
        break;

    }
    db->count  = ++gps_cmd_count;
    *lenp = 0;                          /* no returning payload */
    return TRUE;
  }

  event void GPSTransmit.send_done() {
    raw_tx_busy = FALSE;
  }


  void minor_event(mon_event_t ev);

  void maj_ev_startup() {
    switch(gmcb.major_state) {
      default:
        gps_panic(101, gmcb.major_state, MON_EV_STARTUP);
        return;

      case GMS_MAJOR_IDLE:
        major_change_state(GMS_MAJOR_SATS_STARTUP, MON_EV_STARTUP);
        call GPSControl.logStats();
        call MajorTimer.startOneShot(GPS_MON_SATS_STARTUP_TIME);
        return;
    }
  }


  void maj_ev_lock(mon_event_t ev) {
    switch(gmcb.major_state) {
      default:                          /* ignore by default */
        return;

      case GMS_MAJOR_SATS_STARTUP:
        major_change_state(GMS_MAJOR_CYCLE, ev);
        call CollectEvent.logEvent(DT_EVENT_GPS_FIRST_LOCK,
                call MajorTimer.getNow() - cycle_start, cycle_start, 0, 0);
        cycle_start = 0;
        call MajorTimer.startOneShot(GPS_MON_CYCLE_TIME);
        minor_event(MON_EV_MAJOR_CHANGED);
        return;
    }
  }


  void maj_ev_mpm_error() {
    switch(gmcb.major_state) {
      default:
        gps_panic(101, gmcb.major_state, MON_EV_MPM_ERROR);
        return;

      case GMS_MAJOR_IDLE:
        major_change_state(GMS_MAJOR_MPM_COLLECT, MON_EV_MPM_ERROR);
        call MajorTimer.startOneShot(GPS_MON_MPM_COLLECT_TIME);
        return;
    }
  }

  void maj_ev_timeout_major() {
    switch(gmcb.major_state) {
      default:
        gps_panic(101, gmcb.major_state, MON_EV_TIMEOUT_MAJOR);
        return;

      case GMS_MAJOR_IDLE:
        call MajorTimer.startOneShot(GPS_MON_CYCLE_TIME);
        major_change_state(GMS_MAJOR_CYCLE, MON_EV_TIMEOUT_MAJOR);
        minor_event(MON_EV_MAJOR_CHANGED);
        return;

      case GMS_MAJOR_CYCLE:
      case GMS_MAJOR_MPM_COLLECT:
        gmcb.msg_count = 0;
        call MajorTimer.startOneShot(GPS_MON_SLEEP);
        major_change_state(GMS_MAJOR_IDLE, MON_EV_TIMEOUT_MAJOR);
        minor_event(MON_EV_MAJOR_CHANGED);
        return;

      case GMS_MAJOR_SATS_STARTUP:
        major_change_state(GMS_MAJOR_SATS_STARTUP, MON_EV_TIMEOUT_MAJOR);
        call MajorTimer.startOneShot(GPS_MON_SATS_STARTUP_TIME);
        minor_event(MON_EV_MAJOR_CHANGED);
        return;
    }
  }

  void maj_ev_cycle() {
    switch(gmcb.major_state) {
      default:
        gps_panic(137, gmcb.major_state, MON_EV_CYCLE);
        return;

      case GMS_MAJOR_CYCLE:             /* already got one */
        return;                         /* ignore request  */

      case GMS_MAJOR_IDLE:
      case GMS_MAJOR_SATS_STARTUP:
      case GMS_MAJOR_MPM_COLLECT:
      case GMS_MAJOR_TIME_COLLECT:
        call MajorTimer.startOneShot(GPS_MON_CYCLE_TIME);
        major_change_state(GMS_MAJOR_CYCLE, MON_EV_CYCLE);
        minor_event(MON_EV_MAJOR_CHANGED);
        return;
    }
  }


  void maj_ev_state_chk() {
    major_change_state(gmcb.major_state, MON_EV_STATE_CHK);
    minor_change_state(gmcb.minor_state, MON_EV_STATE_CHK);
  }


  void major_event(mon_event_t ev) {
    verify_gmcb();
    switch(ev) {
      default:
        gps_panic(101, gmcb.major_state, ev);

      case MON_EV_STARTUP:          maj_ev_startup();       return;
      case MON_EV_LOCK_POS:
      case MON_EV_LOCK_TIME:        maj_ev_lock(ev);        return;
      case MON_EV_MPM_ERROR:        maj_ev_mpm_error();     return;
      case MON_EV_TIMEOUT_MAJOR:    maj_ev_timeout_major(); return;
      case MON_EV_CYCLE:            maj_ev_cycle();         return;
      case MON_EV_STATE_CHK:        maj_ev_state_chk();     return;
    }
  }


  void mon_ev_timeout_minor() {
    uint32_t awake, err;

    call GPSControl.logStats();
    switch(gmcb.minor_state) {
      default:
        gps_panic(101, gmcb.minor_state, gmcb.major_state);

      case GMS_CONFIG:
        gmcb.retry_count++;
        call CollectEvent.logEvent(DT_EVENT_GPS_SWVER_TO,
                                   gmcb.retry_count, 0, 0, 0);
        minor_change_state(GMS_CONFIG, MON_EV_TIMEOUT_MINOR);
        if (gmcb.retry_count > 15) {
          /* need to put subsystem disable here. */
          gps_warn(135, gmcb.minor_state, gmcb.retry_count);
          call MinorTimer.startOneShot(GPS_MON_SWVER_TO);
          gmcb.retry_count = 0;         /* start over for now */
          /* for now fall through. */
        }

        /*
         * number of weird start up cases.  For now we handle...
         *
         * if not seeing any messages, pulse the puppy....  Strange
         * that we aren't seeing anything.  We were able to start up
         * so that says that we can see stuff.
         *
         * if seeing messages, great.  But these messages could be
         * from MPM mode (NAVDATAs) but if in MPM mode the stupid chip
         * won't respond to SWVER.  awake only says turn on external
         * rx hardware.
         *
         * So it seems until we do something different wrt to initial
         * turn on, the thing to do is simply always pulse the beast.
         *
         * If not seeing messages (chip sleeping), should turn it on.
         *
         * If seeing messages and the original SWVER was dropped for
         * some reason, the pulse will turn the chip off, we will timeout
         * again and then turn it back on.  So if we are dropping SWVER
         * or its response for some reason we will bounce, try again, and
         * then bounce.
         *
         * If seeing messages and we are in MPM, then the chip is ignoring
         * SWVER, pulsing will kick it out of MPM and the next SWVER
         * should work.
         *
         * sigh.
         *
         * so for now we pulse on even retry counts, this give the SWVER
         * a chance to actually work.  Pulsing and then sending immediately
         * is problematic so this kludge seems reasonable.
         */

        /* always pulse */
        gmcb.msg_count = 0;
        if ((gmcb.retry_count & 1) == 0) {      /* pulse on even */
          call GPSControl.pulseOnOff();
          call CollectEvent.logEvent(DT_EVENT_GPS_PULSE, gmcb.retry_count, 0,
                                     0, call GPSControl.awake());
        }
        call GPSTransmit.send((void *) sirf_swver, sizeof(sirf_swver));
        call MinorTimer.startOneShot(GPS_MON_SWVER_TO);
        return;

      case GMS_COMM_CHECK:
        if (gmcb.retry_count < 6) {
          /*
           * Didn't hear anything, pulse and listen for LONG TO
           */
          gmcb.retry_count++;
          minor_change_state(GMS_COMM_CHECK, MON_EV_TIMEOUT_MINOR);
          call GPSControl.pulseOnOff();
          call MinorTimer.startOneShot(GPS_MON_LONG_COMM_TO);
          return;
        }
        /*
         * we tried 5 times.  yell and scream.
         * subsystem fail.
         */
        call MinorTimer.stop();
        call MajorTimer.stop();
        minor_change_state(GMS_FAIL, MON_EV_TIMEOUT_MINOR);
        gps_panic(136, gmcb.minor_state, gmcb.retry_count);
        return;

      case GMS_COLLECT:
        mon_pulse_comm_check(MON_EV_TIMEOUT_MINOR);
        return;

      case GMS_MPM_WAIT:                /* waiting for mpm rsp */
        if (gmcb.retry_count > 5) {
          /*
           * haven't seen the response to the mpm request, 5 times.
           * panic/warn and kick MPM_COLLECT
           *
           * (not yet).
           */
          gps_warn(136, gmcb.minor_state, gmcb.major_state);
          major_event(MON_EV_MPM_ERROR);
          mon_pulse_comm_check(MON_EV_TIMEOUT_MINOR);
          return;
        }
        minor_change_state(GMS_MPM_WAIT, MON_EV_TIMEOUT_MINOR);
        gmcb.retry_count++;
        awake = call GPSControl.awake();
        err   = call GPSTransmit.send((void *) sirf_go_mpm_0,
                                      sizeof(sirf_go_mpm_0));
        call CollectEvent.logEvent(DT_EVENT_GPS_MPM, 100, err, 0, awake);
        call MinorTimer.startOneShot(GPS_MON_MPM_RSP_TO);
        return;

      case GMS_MPM_RESTART:             /* shutdown timeout, mpm fail */
        mon_pulse_comm_check(MON_EV_TIMEOUT_MINOR);
        return;
    }
    return;
  }

  void mon_ev_major_changed() {
    call GPSControl.logStats();
    switch(gmcb.minor_state) {
      default:
        break;

      case GMS_COLLECT:
        mon_enter_comm_check(MON_EV_MAJOR_CHANGED);
        break;

      case GMS_MPM:                     /* expiration of gps_sense    */
        TELL = 1;
        cycle_start = call MinorTimer.getNow();
        cycle_count++;
        gmcb.lock_seen = FALSE;
        mon_pulse_comm_check(MON_EV_MAJOR_CHANGED);
        break;
    }
  }

  void mon_ev_swver() {
    /*
     * Startup, 1st swver, transition to COLLECT
     * Otherwise, just ignore it.
     */
    if (gmcb.minor_state == GMS_CONFIG) {
      major_event(MON_EV_STARTUP);
      call MinorTimer.startOneShot(GPS_MON_COLLECT_DEADMAN);
      minor_change_state(GMS_COLLECT, MON_EV_SWVER);
    }
  }

  void mon_ev_msg() {
    uint32_t awake, err;

    gmcb.msg_count++;
    switch(gmcb.minor_state) {
      default:
        return;

      case GMS_COMM_CHECK:
        if (gmcb.major_state == GMS_MAJOR_IDLE) {
          minor_change_state(GMS_MPM_WAIT, MON_EV_MSG);
          gmcb.retry_count = 0;
          awake = call GPSControl.awake();
          err   = call GPSTransmit.send((void *) sirf_go_mpm_0,
                                        sizeof(sirf_go_mpm_0));
          call CollectEvent.logEvent(DT_EVENT_GPS_MPM, 101, err, 0, awake);
          call MinorTimer.startOneShot(GPS_MON_MPM_RSP_TO);
          return;
        }
        /*
         * not IDLE,       kick back into COLLECT
         */
        call MinorTimer.startOneShot(GPS_MON_COLLECT_DEADMAN);
        minor_change_state(GMS_COLLECT, MON_EV_MSG);
        return;

      case GMS_COLLECT:
        call MinorTimer.startOneShot(GPS_MON_COLLECT_DEADMAN);
        /*
         * we could do a minor_change_state, COLLECT -> COLLECT
         * but it is way too chatty.
         */
//      minor_change_state(GMS_COLLECT, MON_EV_MSG);
        return;
    }
  }

  void mon_ev_ots_no() {
    switch(gmcb.minor_state) {
      default:
        return;

      case GMS_CONFIG:
        call GPSControl.pulseOnOff();
        minor_change_state(GMS_CONFIG, MON_EV_OTS_NO);
        return;

      case GMS_COMM_CHECK:
      case GMS_COLLECT:
      case GMS_MPM_WAIT:
      case GMS_MPM_RESTART:
      case GMS_MPM:
        break;
    }
    mon_pulse_comm_check(MON_EV_OTS_NO);
  }

  void mon_ev_ots_yes()  { }

  void mon_ev_lock(mon_event_t ev) {
    uint32_t elapsed;

    gmcb.lock_seen = TRUE;

    /*
     * when looking for first lock, cycle_count will be zero
     * (haven't actually started a cycle (happens out of MPM)).
     *
     * if cycle_count is 0 we are looking for first lock. (SATS_STARTUP).
     * leave cycle_count alone and let the major state change grab it.
     */
    if (ev == MON_EV_LOCK_TIME && cycle_count && cycle_start) {
      elapsed = call MinorTimer.getNow() - cycle_start;
      cycle_sum += elapsed;
      call CollectEvent.logEvent(DT_EVENT_GPS_MTFF_TIME, cycle_count,
                                 elapsed, cycle_sum/cycle_count, 0);
      cycle_start = 0;
    }
    major_event(ev);
  }

  /* mpm attempted, and got a good response */
  void mon_ev_mpm() {
    switch(gmcb.minor_state) {
      default:
        gps_warn(138, gmcb.minor_state, 0);
        return;

      case GMS_MPM_WAIT:
        TELL = 0;
        call MinorTimer.stop();
        minor_change_state(GMS_MPM, MON_EV_MPM);
        return;
    }
  }

  /* bad response from mpm */
  void mon_ev_mpm_error() {
    switch(gmcb.minor_state) {
      default:
        gps_warn(138, gmcb.minor_state, 0);
        return;

      case GMS_MPM_WAIT:
        major_event(MON_EV_MPM_ERROR);
        call MinorTimer.startOneShot(GPS_MON_MPM_RESTART_WAIT);
        minor_change_state(GMS_MPM_RESTART, MON_EV_MPM_ERROR);
        return;
    }
  }


  /*
   * Monitor State Machine
   */
  void minor_event(mon_event_t ev) {
    verify_gmcb();
    switch(ev) {
      default:
        gps_panic(100, gmcb.minor_state, ev);

      case MON_EV_SWVER:            mon_ev_swver();         return;
      case MON_EV_MSG:              mon_ev_msg();           return;
      case MON_EV_OTS_NO:           mon_ev_ots_no();        return;
      case MON_EV_OTS_YES:          mon_ev_ots_yes();       return;
      case MON_EV_LOCK_POS:
      case MON_EV_LOCK_TIME:        mon_ev_lock(ev);        return;
      case MON_EV_MPM:              mon_ev_mpm();           return;
      case MON_EV_MPM_ERROR:        mon_ev_mpm_error();     return;
      case MON_EV_TIMEOUT_MINOR:    mon_ev_timeout_minor(); return;
      case MON_EV_MAJOR_CHANGED:    mon_ev_major_changed(); return;
    }
  }


  /*
   * MID 2: NAV_DATA
   */
  void process_navdata(sb_nav_data_t *np, rtctime_t *rtp) {
    uint8_t    pmode;
    gps_xyz_t *mxp;

    nop();
    nop();
    if (!np || CF_BE_16(np->len) != NAVDATA_LEN)
      return;

    if (last_nsats_count == 0 || np->nsats != last_nsats_seen) {
      call CollectEvent.logEvent(DT_EVENT_GPS_SATS_2, np->nsats, np->mode1,
                                 0, call GPSControl.awake());
      last_nsats_seen = np->nsats;
      last_nsats_count = LAST_NSATS_COUNT_INIT;
    } else
      last_nsats_count--;

    pmode = np->mode1 & SB_NAV_M1_PMODE_MASK;
    if (pmode >= SB_NAV_M1_PMODE_SV2KF && pmode <= SB_NAV_M1_PMODE_SVODKF) {
      /*
       * we consider a valid fix anywhere from a 2D (2SV KF fix) to an over
       * determined >= 5 sat fix.
       */
      nop();
      mxp = &m_xyz;
      call Rtc.copyTime(&mxp->rt, rtp);
      mxp->tow   = CF_BE_32(np->tow);
      mxp->week  = CF_BE_16(np->week);
      mxp->x     = CF_BE_32(np->xpos);
      mxp->y     = CF_BE_32(np->ypos);
      mxp->z     = CF_BE_32(np->zpos);
      mxp->mode1 = np->mode1;
      mxp->hdop  = np->hdop;
      mxp->nsats = np->nsats;
      call CollectEvent.logEvent(DT_EVENT_GPS_XYZ, mxp->nsats,
                                 mxp->x, mxp->y, mxp->z);
      minor_event(MON_EV_LOCK_POS);
    }
  }


  /*
   * MID 6: SW VERSION/GPS VERSION
   */
  void process_swver(sb_soft_version_data_t *svp, rtctime_t *rtp) {
    dt_gps_t gps_block;
    uint16_t dlen;

    if (!svp) return;
    dlen = CF_BE_16(svp->len) - 1;
    gps_block.len = dlen + sizeof(gps_block);
    gps_block.dtype = DT_GPS_VERSION;
    call Rtc.copyTime(&gps_block.rt, rtp);
    gps_block.mark_us  = 0;
    gps_block.chip_id = CHIP_GPS_GSD4E;
    gps_block.dir = GPS_DIR_RX;         /* rx from gps */
    call Collect.collect_nots((void *) &gps_block, sizeof(gps_block),
                              svp->data, dlen);
    minor_event(MON_EV_SWVER);
  }


  /*
   * MID 7: CLOCK_STATUS
   */
  void process_clockstatus(sb_clock_status_data_t *cp, rtctime_t *rtp) { }


  /*
   * MID 18: Ok To Send (OTS)
   * 1st byte following the mid (data[0]) indicates yes (1) or no (0).
   */
  void process_ots(sb_header_t *sbp, rtctime_t *rtp) {
    if (sbp->data[0] == 0)
      minor_event(MON_EV_OTS_NO);
    else if (sbp->data[0] == 1)
      minor_event(MON_EV_OTS_YES);
    else
      gps_panic(137, (parg_t) sbp, sbp->data[0]);
  }


  /*
   * MID 41: GEODETIC_DATA
   * Extract time and position data out of the geodetic gps packet
   */
  void process_geodetic(sb_geodetic_t *gp, rtctime_t *rtp) {
    gps_time_t    *mtp;
    gps_geo_t     *mgp;
    uint16_t       nav_valid, nav_type;

    if (!gp || CF_BE_16(gp->len) != GEODETIC_LEN)
      return;

    nav_valid = CF_BE_16(gp->nav_valid);
    nav_type  = CF_BE_16(gp->nav_type);
    if (last_nsats_count == 0 || gp->nsats != last_nsats_seen) {
      call CollectEvent.logEvent(DT_EVENT_GPS_SATS_41, gp->nsats, nav_valid,
                                 nav_type, call GPSControl.awake());
      last_nsats_seen = gp->nsats;
      last_nsats_count = LAST_NSATS_COUNT_INIT;
    } else
      last_nsats_count--;

    if (nav_valid == 0) {
      mtp = &m_time;
      call Rtc.copyTime(&mtp->rt, rtp);
      mtp->tow       = CF_BE_32(gp->tow);
      mtp->week_x    = CF_BE_16(gp->week_x);
      mtp->nsats     = gp->nsats;

      mtp->utc_year  = CF_BE_16(gp->utc_year);
      mtp->utc_month = gp->utc_month;
      mtp->utc_day   = gp->utc_day;
      mtp->utc_hour  = gp->utc_hour;
      mtp->utc_min   = gp->utc_min;
      mtp->utc_ms    = CF_BE_16(gp->utc_ms);
      call CollectEvent.logEvent(DT_EVENT_GPS_TIME,
        (mtp->utc_year << 16) | (mtp->utc_month << 8) | (mtp->utc_day),
        (mtp->utc_hour << 8) | (mtp->utc_min),
        mtp->utc_ms, 0);

      mgp = &m_geo;
      call Rtc.copyTime(&mgp->rt, rtp);
      mgp->tow       = CF_BE_32(gp->tow);
      mgp->week_x    = CF_BE_16(gp->week_x);
      mgp->nsats     = gp->nsats;
      mgp->lat       = CF_BE_32(gp->lat);
      mgp->lon       = CF_BE_32(gp->lon);
      mgp->ehpe      = CF_BE_32(gp->ehpe);
      mgp->hdop      = gp->hdop;
      mgp->sat_mask  = CF_BE_32(gp->sat_mask);
      mgp->nav_valid = CF_BE_16(gp->nav_valid);
      mgp->nav_type  = CF_BE_16(gp->nav_type);
      mgp->alt_ell   = CF_BE_32(gp->alt_elipsoid);
      mgp->alt_msl   = CF_BE_32(gp->alt_msl);
      mgp->sog       = CF_BE_16(gp->sog);
      mgp->cog       = CF_BE_16(gp->cog);
      mgp->additional_mode = gp->additional_mode;
      call CollectEvent.logEvent(DT_EVENT_GPS_GEO, mgp->lat, mgp->lon,
                                 mgp->week_x, mgp->tow);

      /* tell the monitor we have lock */
      minor_event(MON_EV_LOCK_TIME);
    }
  }


  /*
   * MID 71: H/W Config Request
   *
   * respond to a h/w config request.  We send an empty
   * h/w config response.
   */
  void process_hw_config_req(sb_header_t *sbh, rtctime_t *rtp) {
    error_t err;

    err   = call GPSTransmit.send((void *) sirf_hw_config_rsp,
                                  sizeof(sirf_hw_config_rsp));
    call CollectEvent.logEvent(DT_EVENT_GPS_HW_CONFIG, err, 0,
                               0, call GPSControl.awake());
  }


  /*
   * MID 90: Power Mode Response
   * response to sending a Pwr_Mode_Req, MPM or Full Power.
   */
  void process_pwr_rsp(sb_pwr_rsp_t *prp, rtctime_t *rtp) {
    uint16_t error;

    /*
     * warning: prp points to a gps buffer which is unaligned
     * and big endian.  beware of multi-byte values.
     */
    error = CF_BE_16(prp->error);
    call CollectEvent.logEvent(DT_EVENT_GPS_MPM_RSP, error, prp->sid,
                               0, call GPSControl.awake());
    if (error == PWR_RSP_MPM_GOOD)
      minor_event(MON_EV_MPM);
    else
      minor_event(MON_EV_MPM_ERROR);
  }


  void process_default(sb_header_t *sbp, rtctime_t *rtp) {
    const uint8_t *msg;
    uint16_t       size;
    uint32_t       awake, err;
    uint8_t        mid;

    if (!sbp || !rtp)
      return;

    mid = sbp->mid;
    switch(mid) {
      default:  size = 0;                    msg = NULL;         break;
      case 9:   size = sizeof(sirf_9_off);   msg = sirf_9_off;   break;
      case 51:  size = sizeof(sirf_51_off);  msg = sirf_51_off;  break;
      case 92:  size = sizeof(sirf_92_off);  msg = sirf_92_off;  break;
      case 93:  size = sizeof(sirf_93_off);  msg = sirf_93_off;  break;
    }
    if (msg) {
      awake = call GPSControl.awake();
      err   = call GPSTransmit.send((void *) msg, size);
      call CollectEvent.logEvent(DT_EVENT_GPS_MSG_OFF, mid, err, 0, awake);
    }
  }


  event void GPSReceive.msg_available(uint8_t *msg, uint16_t len,
        rtctime_t *arrival_rtp, uint32_t mark_j) {
    sb_header_t *sbp;
    dt_gps_t hdr;

    sbp = (void *) msg;
    if (sbp->start1 != SIRFBIN_A0 || sbp->start2 != SIRFBIN_A2) {
      call Panic.warn(PANIC_GPS, 134, sbp->start1, sbp->start2,
                       (parg_t) msg, len);
      return;
    }

    if (sbp->mid == MID_GPIO && sbp->data[0] == SID_GPIO) {
      /*
       * GPIO message are useless.  We tried disabling them via setMsgRate
       * but it rejected (NACK).  So always punt them.  When we are active
       * we see them once a second.  If we are in MPM, we don't see them
       * at all.
       */
      return;
    }

    if (call OverWatch.getLoggingFlag(OW_LOG_RAW_GPS)) {
      /*
       * gps msg eavesdropping.  Log received messages to the dblk
       * stream.
       */
      hdr.len      = sizeof(hdr) + len;
      hdr.dtype    = DT_GPS_RAW_SIRFBIN;
      call Rtc.copyTime(&hdr.rt, arrival_rtp);
      hdr.mark_us  = (mark_j * MULT_JIFFIES_TO_US) / DIV_JIFFIES_TO_US;
      hdr.chip_id  = CHIP_GPS_GSD4E;
      hdr.dir      = GPS_DIR_RX;
      call Collect.collect_nots((void *) &hdr, sizeof(hdr), msg, len);
    }

    minor_event(MON_EV_MSG);

    switch (sbp->mid) {
      case MID_NAVDATA:
        process_navdata((void *) sbp, arrival_rtp);
        break;
      case MID_SWVER:
        process_swver((void *) sbp, arrival_rtp);
        break;
      case MID_CLOCKSTATUS:
        process_clockstatus((void *) sbp, arrival_rtp);
        break;
      case MID_OTS:
        process_ots((void *) sbp, arrival_rtp);
        break;
      case MID_GEODETIC:
        process_geodetic((void *) sbp, arrival_rtp);
        break;
      case MID_HW_CONFIG_REQ:
        process_hw_config_req((void *) sbp, arrival_rtp);
        break;
      case MID_PWR_MODE_RSP:
        process_pwr_rsp((void *) sbp, arrival_rtp);
      default:
        process_default((void *) sbp, arrival_rtp);
        break;
    }
  }


  event void MinorTimer.fired() {
    minor_event(MON_EV_TIMEOUT_MINOR);
  }

  event void MajorTimer.fired() {
    major_event(MON_EV_TIMEOUT_MAJOR);
  }


  task void monitor_pwr_task() {
    if (!call GPSPwr.isPowered()) {
      call MinorTimer.stop();
      call MajorTimer.stop();
      minor_change_state(GMS_OFF, MON_EV_PWR_OFF);
      major_change_state(GMS_MAJOR_IDLE, MON_EV_PWR_OFF);
    }
  }

  async event void GPSPwr.pwrOn()  { }

  async event void GPSPwr.pwrOff() {
    post monitor_pwr_task();
  }

  event void Collect.collectBooted()    { }
  event void GPSControl.gps_shutdown()  { }
  event void GPSControl.standbyDone()   { }

  event void Collect.resyncDone(error_t err, uint32_t offset) { }

  async event void Panic.hook()         { }
}
