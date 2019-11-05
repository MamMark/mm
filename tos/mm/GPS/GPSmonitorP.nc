/*
 * Copyright (c) 2017-2019 Eric B. Decker
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
 * CONFIG       configuation messages, terminate with a initDataSrc
 *
 * COMM_CHECK   Make sure we can communicate with the gps.  Control
 *              entry to LP (low pwr) (Sleeping, IDLE, MPM) or COLLECT
 *              (awake, CYCLE, LP_COLLECT).
 *
 * COLLECT      collecting fixes (awake, CYCLE, LP_COLLECT).  grabbing
 *              almanac, ephemeri, time calibration.
 *
 * LP_WAIT      low power (sleep or mpm) has been requested.  looking
 *              for response.
 *
 * LP_RESTART   low power didn't work (error response).  The gps may have
 *              shutdown, we probe and will restart if necessary.
 *
 * LP           in low power mode.
 *
 * STANDBY      in Standby
 *
 *********
 *
 * Major States
 *
 * IDLE         sleeping, MPM cycles or hibernate
 * CYCLE        simple fix cycle
 * LP_COLLECT   collecting fixes to help MPM or low pwr heal.
 * SATS_COLLECT collecting fixes for almanac and ephemis collection
 * TIME_COLLECT collecting fixes when doing time syncronization
 * FIX_DELAY    leaving CYCLE due to fix seen, staying up just a bit more.
 *              Usually to let status msgs be seen after a fix.
 */


#include <overwatch.h>
#include <TagnetTLV.h>
#include <sirf_msg.h>
#include <mm_byteswap.h>
#include <sirf_driver.h>
#include <gps_mon.h>
#include <rtctime.h>

/*
 * define GPS_USE_MPM to use MPM mode of the SirfStarIV for low power,
 *     otherwise, low power mode is standby vs. MPM.
 *
 * define GPS_FIX_ENDS_CYCLE to enable receipt of a FIX, either FIX
 *     or TIME, to end the cycle and enter low power.
 */

//#define GPS_USE_MPM
#define GPS_FIX_ENDS_CYCLE
//#define GPS_TIME_ENDS_CYCLE

#ifndef PANIC_GPS
enum {
  __pcode_gps = unique(UQ_PANIC_SUBSYS)
};

#define PANIC_GPS __pcode_gps
#endif


#define GPS_MON_SWVER_TO            1024
#define GPS_MON_SHORT_COMM_TO       2048
#define GPS_MON_LONG_COMM_TO        8192
#define GPS_MON_LPM_RSP_TO          2048
#define GPS_MON_LPM_RESTART_WAIT    2048
#define GPS_MON_COLLECT_DEADMAN     16384

#define GPS_ACK_TIMEOUT             1024

/*
 * 60 secs, we have observed slow start up times of around 60 secs, so for now
 * use a max_cycle of 1 min.  We end the cycle at first fix.  (non-zero mode)
 *
 * We use a short fix_delay to conserve power.
 */
#define GPS_MON_MAX_CYCLE_TIME      ( 1 * 60 * 1024)
#define GPS_MON_LPM_COLLECT_TIME    ( 1 * 60 * 1024)
#define GPS_MON_FIX_DELAY_TIME      (             2)
//#define GPS_MON_FIX_DELAY_TIME      (15 * 60 * 1024)

// 5 mins
#define GPS_MON_SATS_STARTUP_TIME   ( 5 * 60 * 1024)

// 5 mins between last cycle and next cycle
#define GPS_MON_SLEEP               ( 5 * 60 * 1024)
//#define GPS_MON_SLEEP               ( 1 * 60 * 1024)

/*
 * lpm_rsp_to   timeout for listening for responses after
 *              going into low power mode (hibernate or mpm req).
 *              If timeout assume off and poke it.
 *
 * lpm_restart_wait  restart window after seeing a low pwr error.
 *              time limit after seeing the error.  should see
 *              an ots_no first but in case we don't this
 *              timer will catch it.
 *
 * collect_deadman  backstop in case COLLECT doesn't see any
 *              messages.  Shouldn't happen.
 *
 * lpm_collect_time following an mpm error we go into collect
 *              to let mpm stablize.
 *
 * cycle_time   time from wake up to next sleep (low pwr mode).
 *              Window allowed for normal cycle, looking for fixes.
 *              (uses MajorTimer)
 *
 * mon_sleep    when in low pwr mode, how long to stay asleep before next fix.
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
  rtctime_t    rt;                      /* rtctime - last seen */
  dt_gps_xyz_t dt;
} gps_xyz_t;


/* from MID 7, clock status */
typedef struct {
  rtctime_t    rt;
  dt_gps_clk_t dt;
} gps_clk_t;


/* from MID 41, geodetic data */
typedef struct {
  rtctime_t    rt;                      /* rtctime - last seen */
  dt_gps_geo_t dt;
} gps_geo_t;


/* extracted from MID 41, Geodetic */
typedef struct {
  rtctime_t     rt;                     /* rtctime - last seen */
  dt_gps_time_t dt;
} gps_time_t;


typedef struct {
  dt_gps_trk_t         dt;              /* needs to be contig  */
  dt_gps_trk_element_t sats[12];        /* contig with above   */
} gps_trk_block_t;


typedef struct {
  rtctime_t            rt;              /* rtctime - last seen */
  gps_trk_block_t      dt_block;
} gps_trk_t;


#define GMCB_MAJIK 0xAF52FFFF

typedef enum {
  GPSM_TXQ_IDLE = 0,                    /* nothing happening */
  GPSM_TXQ_SENDING,                     /* send a msg */
  GPSM_TXQ_DELAY,                       /* delaying after a send */
  GPSM_TXQ_DRAIN,                       /* draining sending bits */
  GPSM_TXQ_ACK_WAIT,                    /* waiting for an ack to come back */
} txq_state_t;

typedef struct {
  uint32_t           majik_a;
  gpsm_state_t       minor_state;           /* monitor basic state - minor */
  gpsm_major_state_t major_state;           /* monitor major state */
  uint16_t           retry_count;
  uint16_t           msg_count;             /* used to tell if we are seeing msgs */
  bool               fix_seen;              /* fix seen in current cycle */
  txq_state_t        txq_state;             /* state of txq system */
  uint8_t            txq_head;              /* index of next message to go out */
  uint8_t            txq_nxt;               /* index of next entry of queue */
  uint8_t            txq_len;               /* how many in queue. */
  uint8_t            txq_retries;           /* msg needs ack, retry count */
  uint8_t            txq_mid_ack;           /* mid needing acking */
  uint32_t           majik_b;
} gps_monitor_control_t;


const uint8_t mids_w_acks[] = { 128, 132, 136, 144, 166, 178, 0 };

/*
 * config msgs end with send swver, which triggers the end of config.
 * at one point we hit the gps chip with a warmstart via msg 128.
 * but this is problematic because the gps processor goes away for
 * a time.  Which complicates getting the swver trigger.
 */
const uint8_t *config_msgs[] = {
//  sirf_7_on,
  sirf_set_mode_degrade,
  sirf_swver,
  NULL,
};


module GPSmonitorP {
  provides {
    interface TagnetAdapter<tagnet_gps_xyz_t> as InfoSensGpsXyz;
    interface TagnetAdapter<tagnet_gps_cmd_t> as InfoSensGpsCmd;
    interface McuPowerOverride;
  } uses {
    interface Boot;                           /* in boot */
    interface GPSControl;
    interface GPSTransmit;
    interface GPSReceive;
    interface PwrReg as GPSPwr;

    interface Collect;
    interface CollectEvent;
    interface Rtc;
    interface CoreTime;

    interface Timer<TMilli> as MinorTimer;
    interface Timer<TMilli> as MajorTimer;
    interface Timer<TMilli> as TxTimer;
    interface Panic;
    interface OverWatch;
    interface TagnetMonitor;
  }
}
implementation {

  gps_monitor_control_t gmcb;           /* gps monitor control block */


#define MAX_GPS_TXQ 16

  uint8_t *txq[MAX_GPS_TXQ];

norace bool    no_deep_sleep;           /* true if we don't want deep sleep */
  uint32_t     cycle_start, cycle_count, cycle_sum;
  uint32_t     last_nsats_seen, last_nsats_count;

#define LAST_NSATS_COUNT_INIT 10

  gps_xyz_t   m_xyz;
  gps_clk_t   m_clk;
  gps_geo_t   m_geo;
  gps_time_t  m_time;
  gps_trk_t   m_track;

  void major_event(mon_event_t ev);

  void gps_warn(uint8_t where, parg_t p, parg_t p1) {
    call Panic.warn(PANIC_GPS, where, p, p1, 0, 0);
  }

  void gps_panic(uint8_t where, parg_t p, parg_t p1) {
    call Panic.panic(PANIC_GPS, where, p, p1, 0, 0);
  }


  bool mid_needs_ack(uint8_t mid) {
    int i;

    for (i = 0; mids_w_acks[i]; i++)
      if (mid == mids_w_acks[i]) return TRUE;
    return FALSE;
  }


  /*
   * txq - gps message queue going to the gps chip
   *
   * The TXQ is used to send various messages to the GPS chip.
   * Status messages and debug messages.
   *
   * The txq only runs when the Minor State machine is in Collect.
   * It gets fired up when we enter COLLECT for any reason and runs
   * until the txq is emptied.
   *
   * When in COLLECT the chip should be listening.
   */

  uint8_t txq_adv(uint8_t idx) {
    idx++;
    if (idx >= MAX_GPS_TXQ)
      idx = 0;
    return idx;
  }


  error_t txq_start() {
    uint8_t *gps_msg;
    uint16_t gps_len;

    if (gmcb.txq_state != GPSM_TXQ_IDLE)
      return EALREADY;
    if (gmcb.txq_len == 0)
      return EOFF;

    if (gmcb.txq_len >= MAX_GPS_TXQ)
      gps_panic(-1, gmcb.txq_len, 0);

    /*
     * head of the queue is assumed to be a sirfbin gps msg
     *
     * 1st two bytes are the SOP following by a big endian uint16 len.
     * not aligned.  So we have to extract the length by hand.
     */
    gps_msg = txq[gmcb.txq_head];
    gps_len = gps_msg[2] << 8 | gps_msg[3];
    if (gps_msg[0] != SIRFBIN_A0 ||
        gps_msg[1] != SIRFBIN_A2 ||
        gps_len > SIRFBIN_MAX_MSG)
      gps_panic(-1, gps_msg[0] << 8 | gps_msg[1], gps_len);
    gps_len += SIRFBIN_OVERHEAD;        /* add in overhead */
    gmcb.txq_state = GPSM_TXQ_SENDING;
    return call GPSTransmit.send(gps_msg, gps_len);
  }


  error_t txq_enqueue(uint8_t *gps_msg) {
    if (gmcb.txq_len == 0) {            /* empty queue */
      txq[gmcb.txq_head] = gps_msg;
      gmcb.txq_nxt = txq_adv(gmcb.txq_head);
      gmcb.txq_len++;
      return SUCCESS;
    }
    if (gmcb.txq_len >= MAX_GPS_TXQ)
      return EBUSY;                     /* no room */
    txq[gmcb.txq_nxt] = gps_msg;
    gmcb.txq_nxt = txq_adv(gmcb.txq_nxt);
    gmcb.txq_len++;
    return SUCCESS;
  }


  /* enqueue and start the queue */
  error_t txq_send(uint8_t *gps_msg) {
    error_t err;

    err = txq_enqueue(gps_msg);
    if (err == SUCCESS)
      err = txq_start();
    return err;
  }


  /*
   * txq_purge: empty the txq and abort any inprogress.
   *
   * if we set state to DRAIN, the send_stop will come back
   * with send_done.
   */
  void txq_purge() {
    switch(gmcb.txq_state) {
      default:
        gps_panic(-1, gmcb.txq_state, 0);
        break;

      case GPSM_TXQ_SENDING:
        gmcb.txq_state = GPSM_TXQ_DRAIN;
        call GPSTransmit.send_stop();
        break;

      case GPSM_TXQ_IDLE:
      case GPSM_TXQ_DELAY:
      case GPSM_TXQ_DRAIN:
      case GPSM_TXQ_ACK_WAIT:
        gmcb.txq_state =  GPSM_TXQ_IDLE;
        call TxTimer.stop();
        break;
    }
    gmcb.txq_head = 0;
    gmcb.txq_nxt  = 0;
    gmcb.txq_len  = 0;
  }


  void enqueue_entry_msgs() {
    /*
     * hint: we get invoked when going into any on state.  But the queue
     * doesn't get fired up until the minor state machine enters collect.
     */
#ifdef notdef
    txq_enqueue((void *) sirf_set_mode_degrade);
    txq_enqueue((void *) sirf_poll_clk_status);
    txq_enqueue((void *) sirf_hotstart_noinit);
#endif
  }

  void enqueue_exit_msgs() {
  }

  void verify_gmcb() {
    if (gmcb.majik_a != GMCB_MAJIK || gmcb.majik_a != GMCB_MAJIK)
      gps_panic(102, (parg_t) &gmcb, 0);
    if (gmcb.minor_state > GMS_MAX || gmcb.major_state > GMS_MAJOR_MAX)
      gps_panic(103, gmcb.minor_state, gmcb.major_state);
  }

  void major_change_state(gpsm_major_state_t new_state, mon_event_t ev) {
    gpsm_major_state_t old_state;

    verify_gmcb();
    old_state = gmcb.major_state;
    if (call OverWatch.getLoggingFlag(OW_LOG_GPS_STATE))
      call CollectEvent.logEvent(DT_EVENT_GPS_MON_MAJOR, old_state,
                                 new_state, ev, 0);
    gmcb.major_state = new_state;
    last_nsats_count = 0;
    if (gmcb.major_state != GMS_MAJOR_IDLE)
      no_deep_sleep = TRUE;
    if (old_state != new_state) {
      if (new_state >= GMS_MAJOR_CYCLE && new_state < GMS_MAJOR_FIX_DELAY)
        enqueue_entry_msgs();
      if (old_state == GMS_MAJOR_CYCLE)
        enqueue_exit_msgs();
    }
  }


  void minor_change_state(gpsm_state_t new_state, mon_event_t ev) {
    gpsm_state_t old_minor_state;

    if (call OverWatch.getLoggingFlag(OW_LOG_GPS_STATE))
      call CollectEvent.logEvent(DT_EVENT_GPS_MON_MINOR, gmcb.minor_state,
                                 new_state, ev, 0);
    old_minor_state = gmcb.minor_state;
    gmcb.minor_state = new_state;
    last_nsats_count = 0;

    if ((old_minor_state == GMS_LPM) &&
        (gmcb.major_state == GMS_MAJOR_CYCLE)) {
      /*
       * if we are exiting LPM and major is CYCLE then we are starting a
       * new cycle.  Update instrumentation.
       */
      cycle_start = call MajorTimer.getNow();
      cycle_count++;
      gmcb.fix_seen = FALSE;
      call CollectEvent.logEvent(DT_EVENT_GPS_CYCLE_START, cycle_count, 0, cycle_start, 0);
    }

    if ((new_state == GMS_LPM) && (gmcb.major_state == GMS_MAJOR_IDLE)) {
      /*
       * entering Low Power Mode, finish the cycle.
       */
      call CollectEvent.logEvent(DT_EVENT_GPS_CYCLE_END, cycle_count,
                call MajorTimer.getNow() - cycle_start, cycle_start, 0);
      cycle_start = 0;
    }

    /* set global no_deep_sleep based on current Major/Minor */
    if (gmcb.major_state != GMS_MAJOR_IDLE)
      no_deep_sleep = TRUE;
    else {
      if ((gmcb.minor_state < GMS_BOOTING) ||
          (gmcb.minor_state == GMS_LPM)    ||
          (gmcb.minor_state == GMS_STANDBY))
        no_deep_sleep = FALSE;
      else
        no_deep_sleep = TRUE;
    }

    /* if we entered collect, start the txq */
    if (gmcb.minor_state == GMS_COLLECT)
      txq_start();
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
    int idx;

    txq_purge();                        /* no left overs */
    switch (gmcb.minor_state) {
      default:
        gps_panic(1, gmcb.minor_state, 0);
        return;
      case GMS_OFF:                     /* coming out of power off */
      case GMS_BOOTING:                 /* or 1st boot */
        gmcb.msg_count   = 0;
        gmcb.retry_count = 0;
        gmcb.fix_seen   = FALSE;
        minor_change_state(GMS_CONFIG, MON_EV_STARTUP);
        call GPSControl.logStats();

        for (idx = 0; config_msgs[idx]; idx++)
          txq_enqueue((void *) config_msgs[idx]);
        txq_start();
        cycle_start = call MajorTimer.getNow();
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
            call MajorTimer.stop();
            call MinorTimer.stop();
            call GPSControl.logStats();
            major_change_state(GMS_MAJOR_IDLE, MON_EV_FAIL);
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
    t->gps_x = m_xyz.dt.x;
    t->gps_y = m_xyz.dt.y;
    t->gps_z = m_xyz.dt.z;
    *l = TN_GPS_XYZ_LEN;
    return 1;
  }

  /* also in tagcore/gps_mon.py  */
  const uint8_t *canned_msgs[] = {
    sirf_peek_0,                        /* 0 */
    sirf_swver,                         /* 1 */
    sirf_factory_reset,                 /* 2 */
    sirf_factory_clear,                 /* 3 */
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
        err = txq_send((void *) sirf_go_mpm_0);
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
          err = txq_send(raw_tx_buf);
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
          err = txq_send((void *) canned_msgs[l]);
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


  void txq_adv_restart() {
    gmcb.txq_mid_ack = 0;
    gmcb.txq_head = txq_adv(gmcb.txq_head);
    gmcb.txq_len--;
    gmcb.txq_state = GPSM_TXQ_IDLE;
    txq_start();                        /* fire next one up */
  }


  event void GPSTransmit.send_done() {
    uint8_t  mid;
    uint8_t *gps_msg;

    switch(gmcb.txq_state) {
      default:
        gps_panic(-1, gmcb.txq_state, 0);
        break;

      case GPSM_TXQ_DRAIN:
        gmcb.txq_state = GPSM_TXQ_IDLE;

        /*
         * It is possible that new messages may have been queued
         * to go out after the purge occurred.  So we call txq_start()
         * after going to IDLE, to restart sending from the queue.
         */
        txq_start();
        break;

      case GPSM_TXQ_SENDING:
        gps_msg = txq[gmcb.txq_head];
        mid = gps_msg[4];
        if (mid_needs_ack(mid)) {
          gmcb.txq_state   = GPSM_TXQ_ACK_WAIT;
          call TxTimer.startOneShot(GPS_ACK_TIMEOUT);

          /* non-zero txq_mid_ack -> mid/ack exchange */
          if (gmcb.txq_mid_ack) return;

          /* first time waiting for ack, set up retries */
          gmcb.txq_mid_ack = mid;
          gmcb.txq_retries = 3;
          return;
        }
        txq_adv_restart();
        break;
    }
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


  void maj_ev_fix(mon_event_t ev) {
    uint32_t elapsed;

    switch(gmcb.major_state) {
      default:                          /* ignore by default */
        return;

      case GMS_MAJOR_SATS_STARTUP:
        /* only TIME (over-determined) gets us out */
        if (ev != MON_EV_TIME)
          return;
        major_change_state(GMS_MAJOR_CYCLE, ev);
        call CollectEvent.logEvent(DT_EVENT_GPS_FIRST_FIX,
                call MajorTimer.getNow() - cycle_start, cycle_start, 0, 0);
        call MajorTimer.startOneShot(GPS_MON_MAX_CYCLE_TIME);
        minor_event(MON_EV_MAJOR_CHANGED);
        return;

      case GMS_MAJOR_CYCLE:
#ifdef GPS_FIX_ENDS_CYCLE
#ifdef GPS_TIME_ENDS_CYCLE
        if (ev != MON_EV_TIME)
          return;
#endif
        /*
         * cycle_count will be 0 while we are first booting the gps and
         * while we are in sats_startup.  Cycle_count goes non-zero on the
         * first transition from (major) xxx -> CYCLE and (minor) LPM ->
         * XXX.  (see minor_change_state).
         *
         * Very first cycle time is reported as FIRST_FIX.  First cycle
         * time is not included in the cycle average.  LTFF is the time
         * from beginning of the cycle until the fix.  Cycle time are from
         * the beginning through any potential fix until the gps is put
         * back to sleep (following fix delay).
         */
        if (cycle_count) {
          elapsed = call MajorTimer.getNow() - cycle_start;
          cycle_sum += elapsed;
          call CollectEvent.logEvent(DT_EVENT_GPS_CYCLE_LTFF, cycle_count,
                                     elapsed, cycle_start, cycle_sum/cycle_count);
        }
        major_change_state(GMS_MAJOR_FIX_DELAY, ev);
        call MajorTimer.startOneShot(GPS_MON_FIX_DELAY_TIME);
        minor_event(MON_EV_MAJOR_CHANGED);
#endif
        return;
    }
  }


  void maj_ev_lpm_error() {
    switch(gmcb.major_state) {
      default:
        gps_panic(101, gmcb.major_state, MON_EV_LPM_ERROR);
        return;

      case GMS_MAJOR_IDLE:
        major_change_state(GMS_MAJOR_LPM_COLLECT, MON_EV_LPM_ERROR);
        call MajorTimer.startOneShot(GPS_MON_LPM_COLLECT_TIME);
        return;
    }
  }

  void maj_ev_timeout_major() {
    switch(gmcb.major_state) {
      default:
        gps_panic(101, gmcb.major_state, MON_EV_TIMEOUT_MAJOR);
        return;

      case GMS_MAJOR_IDLE:
        call MajorTimer.startOneShot(GPS_MON_MAX_CYCLE_TIME);
        major_change_state(GMS_MAJOR_CYCLE, MON_EV_TIMEOUT_MAJOR);
        minor_event(MON_EV_MAJOR_CHANGED);
        return;

      case GMS_MAJOR_SATS_STARTUP:
      case GMS_MAJOR_CYCLE:
      case GMS_MAJOR_LPM_COLLECT:
      case GMS_MAJOR_FIX_DELAY:
        gmcb.msg_count = 0;
        call MajorTimer.startOneShot(GPS_MON_SLEEP);
        major_change_state(GMS_MAJOR_IDLE, MON_EV_TIMEOUT_MAJOR);
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
      case GMS_MAJOR_LPM_COLLECT:
      case GMS_MAJOR_TIME_COLLECT:
      case GMS_MAJOR_FIX_DELAY:
        call MajorTimer.startOneShot(GPS_MON_MAX_CYCLE_TIME);
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
      case MON_EV_FIX:
      case MON_EV_TIME:             maj_ev_fix(ev);         return;
      case MON_EV_LPM_ERROR:        maj_ev_lpm_error();     return;
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
         * If we have an init msg (initDataSrc) or any message that causes
         * a gps restart/reset in configuration messages (hey, it's possible,
         * depends on what we are trying to break :-), sending a swver
         * will hit the dead zone, we will time out and resend.
         *
         * If seeing messages and we are in LPM, then the chip is ignoring
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
        txq_send((void *) sirf_swver);
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

      case GMS_LPM_WAIT:                /* waiting for low pwr rsp */
        if (gmcb.retry_count > 5) {
          /*
           * haven't seen the response to low pwr entry, 5 times.
           * panic/warn and kick LPM_COLLECT
           *
           * (not yet).
           */
          gps_warn(136, gmcb.minor_state, gmcb.major_state);
          major_event(MON_EV_LPM_ERROR);
          mon_pulse_comm_check(MON_EV_TIMEOUT_MINOR);
          return;
        }
        minor_change_state(GMS_LPM_WAIT, MON_EV_TIMEOUT_MINOR);
        gmcb.retry_count++;
        awake = call GPSControl.awake();
#ifdef GPS_USE_MPM
        err = txq_send((void *) sirf_go_mpm_0);
#else
        err = 0;
#endif
        call CollectEvent.logEvent(DT_EVENT_GPS_MPM, 100, err, 0, awake);
        call MinorTimer.startOneShot(GPS_MON_LPM_RSP_TO);
        return;

      case GMS_LPM_RESTART:             /* shutdown timeout, lpm fail */
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

      case GMS_LPM:
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
          /*
           * Major indicates we want to quiese the GPS.
           */
#ifdef GPS_USE_MPM
          minor_change_state(GMS_LPM_WAIT, MON_EV_MSG);
          gmcb.retry_count = 0;
          awake = call GPSControl.awake();
          err = txq_send((void *) sirf_go_mpm_0);
          call CollectEvent.logEvent(DT_EVENT_GPS_LPM, 101, err, 0, awake);
          call MinorTimer.startOneShot(GPS_MON_LPM_RSP_TO);
          return;
#else
          /*
           * Not using MPM, just pulse it off
           */
          minor_change_state(GMS_LPM_WAIT, MON_EV_MSG);
          gmcb.retry_count = 0;
          err = 0;
          awake = call GPSControl.awake();
          call GPSControl.pulseOnOff();

          /* should get a OTS-no back. */
          call CollectEvent.logEvent(DT_EVENT_GPS_MPM, 101, err, 0, awake);
          call MinorTimer.startOneShot(GPS_MON_LPM_RSP_TO);
          return;
#endif
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
    txq_purge();
    switch(gmcb.minor_state) {
      default:
        return;

      case GMS_CONFIG:
        call GPSControl.pulseOnOff();
        minor_change_state(GMS_CONFIG, MON_EV_OTS_NO);
        return;

      case GMS_LPM:
      case GMS_LPM_WAIT:
        call MinorTimer.stop();
        minor_change_state(GMS_LPM, MON_EV_LPM);
        return;

      case GMS_COMM_CHECK:
      case GMS_COLLECT:
      case GMS_LPM_RESTART:
        break;
    }
    mon_pulse_comm_check(MON_EV_OTS_NO);
  }

  void mon_ev_ots_yes()  {
    switch (gmcb.minor_state) {
      default:
        break;

      case GMS_CONFIG:
        txq_send((void *) sirf_swver);
        break;
    }
  }

  void mon_ev_fix(mon_event_t ev) {
    gmcb.fix_seen = TRUE;
    major_event(ev);
  }

  /* low pwr (mpm) attempted, and got a good response */
  void mon_ev_lpm() {
    switch(gmcb.minor_state) {
      default:
        gps_warn(138, gmcb.minor_state, 0);
        return;

      case GMS_LPM:
      case GMS_LPM_WAIT:
        TELL = 0;
        call MinorTimer.stop();
        minor_change_state(GMS_LPM, MON_EV_LPM);
        return;
    }
  }

  /* bad response from mpm */
  void mon_ev_lpm_error() {
    switch(gmcb.minor_state) {
      default:
        gps_warn(138, gmcb.minor_state, 0);
        return;

      case GMS_LPM_WAIT:
        major_event(MON_EV_LPM_ERROR);
        call MinorTimer.startOneShot(GPS_MON_LPM_RESTART_WAIT);
        minor_change_state(GMS_LPM_RESTART, MON_EV_LPM_ERROR);
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
      case MON_EV_FIX:
      case MON_EV_TIME:             mon_ev_fix(ev);         return;
      case MON_EV_LPM:              mon_ev_lpm();           return;
      case MON_EV_LPM_ERROR:        mon_ev_lpm_error();     return;
      case MON_EV_TIMEOUT_MINOR:    mon_ev_timeout_minor(); return;
      case MON_EV_MAJOR_CHANGED:    mon_ev_major_changed(); return;
    }
  }


  /*
   * MID 2: NAV_DATA
   */
  void process_navdata(sb_nav_data_t *np, rtctime_t *rtp) {
    dt_gps_t      gps_block;
    dt_gps_xyz_t *xdtp;
    uint8_t       pmode;
    int           i;

    uint64_t       epoch;
    uint32_t       cur_secs,   cap_secs;
    uint32_t       cur_micros, cap_micros;
    uint32_t       delta, sat_mask;
    rtctime_t      cur_time;

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
    if (pmode) {
      /* any nonzero mode is a valid fix. */
      xdtp = &m_xyz.dt;
      call Rtc.copyTime(&m_xyz.rt, rtp);
      xdtp->x      = CF_BE_32(np->xpos);
      xdtp->y      = CF_BE_32(np->ypos);
      xdtp->z      = CF_BE_32(np->zpos);
      xdtp->tow100 = CF_BE_32(np->tow100);
      if (m_clk.dt.week_x != 0)
        xdtp->week_x = m_clk.dt.week_x;
      else
        xdtp->week_x = CF_BE_16(np->week10) + 2048;
      xdtp->m1     = np->mode1;
      xdtp->hdop5  = np->hdop5;
      xdtp->nsats  = np->nsats;
      sat_mask = 0;
      for (i = 0; i < 12; i++)          /* are there always 12 datams? */
        if (np->data[i])
          sat_mask |= (1 << (np->data[i] - 1));
      xdtp->sat_mask = sat_mask;

      epoch = call Rtc.rtc2epoch(rtp);
      cap_secs   = epoch >> 32;
      cap_micros = epoch & 0xffffffffUL;

      call Rtc.getTime(&cur_time);
      epoch      = call Rtc.rtc2epoch(&cur_time);
      cur_secs   = epoch >> 32;
      cur_micros = epoch & 0xffffffffUL;

      delta = (cur_secs - cap_secs) * 1000000 + (cur_micros - cap_micros);
      xdtp->capdelta = delta;

      /* build the dt gps header */
      gps_block.len = sizeof(gps_block) + sizeof(dt_gps_xyz_t);
      gps_block.dtype = DT_GPS_XYZ;
      gps_block.mark_us = 0;
      gps_block.chip_id = CHIP_GPS_GSD4E;
      gps_block.dir     = GPS_DIR_RX;
      call Collect.collect((void *) &gps_block, sizeof(gps_block),
                           (void *) xdtp, sizeof(*xdtp));
      minor_event(MON_EV_FIX);
    }
  }


  /*
   * MID 4: Nav Track
   */
  void process_navtrack(sb_tracker_data_t *tp, rtctime_t *rtp) {
    dt_gps_t              gps_block;
    dt_gps_trk_t         *tdtp;
    dt_gps_trk_element_t *tedtp;
    sb_tracker_element_t *sb_elem;
    int                   i;

    uint64_t              epoch;
    uint32_t              cur_secs,   cap_secs;
    uint32_t              cur_micros, cap_micros;
    uint32_t              delta;
    rtctime_t             cur_time;
    uint8_t               *a, *b;

    tdtp = &m_track.dt_block.dt;
    call Rtc.copyTime(&m_track.rt, rtp);

    tdtp->tow100 = CF_BE_32(tp->tow100);
    tdtp->week10 = CF_BE_16(tp->week10);
    tdtp->chans  = tp->chans;
    tedtp        = &m_track.dt_block.sats[0];

    for (i = 0; i < 12; i++) {
      sb_elem      = &tp->sats[i];
      tedtp->az10  = sb_elem->az23 * 3 * 10 / 2;
      tedtp->el10  = sb_elem->el2  * 10 / 2;
      tedtp->state = sb_elem->state[0] << 8 | sb_elem->state[1];
      tedtp->svid  = sb_elem->svid;

      /*
       * don't use memcpy which assumes aligned, sb_elem is random
       * and not properly structured.  Just unroll it.
       */
      a = &tedtp->cno[0];
      b = &sb_elem->cno[0];
      a[0] = b[0];  a[1] = b[1];  a[2] = b[2];
      a[3] = b[3];  a[4] = b[4];  a[5] = b[5];
      a[6] = b[6];  a[7] = b[7];  a[8] = b[8];
      a[9] = b[9];
      tedtp++;
    }

    epoch = call Rtc.rtc2epoch(rtp);
    cap_secs   = epoch >> 32;
    cap_micros = epoch & 0xffffffffUL;

    call Rtc.getTime(&cur_time);
    epoch      = call Rtc.rtc2epoch(&cur_time);
    cur_secs   = epoch >> 32;
    cur_micros = epoch & 0xffffffffUL;

    delta = (cur_secs - cap_secs) * 1000000 + (cur_micros - cap_micros);
    tdtp->capdelta = delta;

    /* build the dt gps header */
    gps_block.len = sizeof(gps_block) + sizeof(gps_trk_block_t);
    gps_block.dtype = DT_GPS_TRK;
    gps_block.mark_us = 0;
    gps_block.chip_id = CHIP_GPS_GSD4E;
    gps_block.dir     = GPS_DIR_RX;
    call Collect.collect((void *) &gps_block, sizeof(gps_block),
         (void *) &m_track.dt_block, sizeof(gps_trk_block_t));
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
   * MID 7: CLOCK STATUS
   */
  void process_clk_status(sb_clock_status_data_t *csp, rtctime_t *rtp) {
    dt_gps_t      gps_block;
    dt_gps_clk_t *cdtp;

    uint64_t      epoch;
    uint32_t      cur_secs,   cap_secs;
    uint32_t      cur_micros, cap_micros;
    uint32_t      delta;
    rtctime_t     cur_time;

    if (!csp) return;

    cdtp = &m_clk.dt;
    call Rtc.copyTime(&m_clk.rt, rtp);
    cdtp->week_x = CF_BE_16(csp->week_x);
    cdtp->tow100 = CF_BE_32(csp->tow100);
    cdtp->nsats  = csp->nsats;
    cdtp->drift  = CF_BE_32(csp->drift);
    cdtp->bias   = CF_BE_32(csp->bias);

    epoch = call Rtc.rtc2epoch(rtp);
    cap_secs   = epoch >> 32;
    cap_micros = epoch & 0xffffffffUL;

    call Rtc.getTime(&cur_time);
    epoch      = call Rtc.rtc2epoch(&cur_time);
    cur_secs   = epoch >> 32;
    cur_micros = epoch & 0xffffffffUL;

    delta = (cur_secs - cap_secs) * 1000000 + (cur_micros - cap_micros);
    cdtp->capdelta = delta;

    /* build the dt gps header */
    gps_block.len = sizeof(gps_block) + sizeof(dt_gps_clk_t);
    gps_block.dtype = DT_GPS_CLK;
    gps_block.mark_us = 0;
    gps_block.chip_id = CHIP_GPS_GSD4E;
    gps_block.dir     = GPS_DIR_RX;
    call Collect.collect((void *) &gps_block, sizeof(gps_block),
                         (void *) cdtp, sizeof(*cdtp));
  }


  /*
   * MID 11 ACK and MID 12 NACK
   */
  void process_ack(sb_acknack_t *anp, rtctime_t *rtp) {
    uint8_t mid;

    if (gmcb.txq_state == GPSM_TXQ_ACK_WAIT) {
      mid = gmcb.txq_mid_ack;
      if (anp->a_mid != mid) {
        call CollectEvent.logEvent(DT_EVENT_GPS_ACK, anp->a_mid, mid, 0, 0);
        return;
      }
      gmcb.txq_mid_ack = 0;
      call TxTimer.stop();
      txq_adv_restart();
    }
  }

  void process_nack(sb_acknack_t *anp, rtctime_t *rtp) {
    uint8_t mid;

    if (gmcb.txq_state == GPSM_TXQ_ACK_WAIT) {
      mid = gmcb.txq_mid_ack;
      gmcb.txq_mid_ack = 0;
      call TxTimer.stop();
      call CollectEvent.logEvent(DT_EVENT_GPS_NACK, anp->a_mid, mid, 0, 0);
      if (mid == anp->a_mid)
        txq_adv_restart();
    }
  }

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
    dt_gps_t       gps_block;
    dt_gps_time_t *tdtp;
    dt_gps_geo_t  *gdtp;
    uint16_t       nav_valid, nav_type;
    uint64_t       epoch;
    uint32_t       cur_secs,   cap_secs;
    uint32_t       cur_micros, cap_micros;
    rtctime_t      cur_time;
    uint16_t       utc_sec, utc_ms;
    rtctime_t      rtc;
    int32_t        delta;
    bool           force;
    int            timesrc, forcesrc;

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

    if ((nav_type & SB_GEO_TYPE_MASK) != 0) {   /* its some kind of fix */
      tdtp = &m_time.dt;
      call Rtc.copyTime(&m_time.rt, rtp);       /* last seen */
      tdtp->tow1000   = CF_BE_32(gp->tow1000);
      tdtp->week_x    = CF_BE_16(gp->week_x);
      tdtp->utc_year  = CF_BE_16(gp->utc_year);
      tdtp->utc_month = gp->utc_month;
      tdtp->utc_day   = gp->utc_day;
      tdtp->utc_hour  = gp->utc_hour;
      tdtp->utc_min   = gp->utc_min;
      tdtp->utc_ms    = CF_BE_16(gp->utc_ms);
      tdtp->nsats     = gp->nsats;

      epoch      = call Rtc.rtc2epoch(rtp);
      cap_secs   = epoch >> 32;
      cap_micros = epoch & 0xffffffffUL;

      call Rtc.getTime(&cur_time);
      epoch      = call Rtc.rtc2epoch(&cur_time);
      cur_secs   = epoch >> 32;
      cur_micros = epoch & 0xffffffffUL;

      delta = (cur_secs - cap_secs) * 1000000 + (cur_micros - cap_micros);
      tdtp->capdelta = delta;

      /* build the dt gps header */
      gps_block.len = sizeof(gps_block) + sizeof(dt_gps_time_t);
      gps_block.dtype = DT_GPS_TIME;
      gps_block.mark_us = 0;
      gps_block.chip_id = CHIP_GPS_GSD4E;
      gps_block.dir     = GPS_DIR_RX;
      call Collect.collect((void *) &gps_block, sizeof(gps_block),
                           (void *) tdtp, sizeof(*tdtp));

      gdtp = &m_geo.dt;
      call Rtc.copyTime(&m_geo.rt, rtp);
      gdtp->nav_valid = CF_BE_16(gp->nav_valid);
      gdtp->nav_type  = CF_BE_16(gp->nav_type);
      gdtp->lat       = CF_BE_32(gp->lat);
      gdtp->lon       = CF_BE_32(gp->lon);
      gdtp->alt_ell   = CF_BE_32(gp->alt_elipsoid);
      gdtp->alt_msl   = CF_BE_32(gp->alt_msl);
      gdtp->sat_mask  = CF_BE_32(gp->sat_mask);
      gdtp->tow1000   = CF_BE_32(gp->tow1000);
      gdtp->week_x    = CF_BE_16(gp->week_x);
      gdtp->nsats     = gp->nsats;
      gdtp->add_mode  = gp->additional_mode;
      gdtp->ehpe100   = CF_BE_32(gp->ehpe);
      gdtp->hdop5     = gp->hdop;

      call Rtc.getTime(&cur_time);
      epoch = call Rtc.rtc2epoch(&cur_time);
      cur_secs   = epoch >> 32;
      cur_micros = epoch & 0xffffffffUL;

      delta = (cur_secs - cap_secs) * 1000000 + (cur_micros - cap_micros);
      gdtp->capdelta = delta;

      /* build the dt gps header */
      gps_block.len = sizeof(gps_block) + sizeof(dt_gps_geo_t);
      gps_block.dtype = DT_GPS_GEO;

      /* the rest of the header cells are the same as for time */
      call Collect.collect((void *) &gps_block, sizeof(gps_block),
                           (void *) gdtp, sizeof(*gdtp));

      /*
       * Having a good time is critical for proper functioning of the
       * radio and the rendezvous problem.
       *
       * We want to set the RTC when any of the following is true.
       *
       * 1) Current timesrc is not GPS (< GPS0).  Set using gps time.
       *    set timesrc GPS0, reboot.
       *
       * 2) utc_ms == 0 -> 1PPS TM -> OD highest caliber gps time.
       *    timesrc < GPS (GPS0 or below) or excessiveSkew.
       *    set timesrc GPS, reboot.
       */
      utc_sec = tdtp->utc_ms / 1000;
      utc_ms  = tdtp->utc_ms - (utc_sec * 1000);

      timesrc = call OverWatch.getRtcSrc();
      force = timesrc < RTCSRC_GPS0;
      forcesrc = RTCSRC_GPS0;
      delta   = 0;
      if (force || utc_ms == 0) {
        rtc.year    = tdtp->utc_year;
        rtc.mon     = tdtp->utc_month;
        rtc.day     = tdtp->utc_day;
        rtc.dow     = 0;
        rtc.hr      = tdtp->utc_hour;
        rtc.min     = tdtp->utc_min;
        rtc.sec     = utc_sec;
        rtc.sub_sec = call Rtc.micro2subsec(utc_ms * 1000);
        if (utc_ms == 0) {
          forcesrc = RTCSRC_GPS;
          force = (force | (timesrc < RTCSRC_GPS));
          force = (force | (call CoreTime.excessiveSkew(&rtc,
                                cur_secs, NULL, NULL, &delta)));
        }
      }
      if (force) {
        call CollectEvent.logEvent(DT_EVENT_TIME_SRC, forcesrc, delta,
                                   timesrc, 2);
        call OverWatch.setRtcSrc(forcesrc);
        call Rtc.syncSetTime(&rtc);
        call OverWatch.flush_boot(call OverWatch.getBootMode(),
                                  ORR_TIME_SKEW);
      }

      /* tell the monitor we have lock */
      if (nav_valid == 0) {             /* overdetermined */
        minor_event(MON_EV_TIME);
        return;
      }
      minor_event(MON_EV_FIX);
    }
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
      minor_event(MON_EV_LPM);
    else
      minor_event(MON_EV_LPM_ERROR);
  }


  void process_default(sb_header_t *sbp, rtctime_t *rtp) {
    const uint8_t *msg;
    uint32_t       awake, err;
    uint8_t        mid;

    if (!sbp || !rtp)
      return;

    mid = sbp->mid;
    switch(mid) {
      default:  msg = NULL;         break;
      case 9:   msg = sirf_9_off;   break;
      case 51:  msg = sirf_51_off;  break;
      case 92:  msg = sirf_92_off;  break;

      /* 93 doesn't respond to msg off */
//      case 93:  msg = sirf_93_off;  break;
    }
    if (msg) {
      awake = call GPSControl.awake();
      err = txq_send((void *) msg);
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

    if (call OverWatch.getLoggingFlag(OW_LOG_GPS_RAW)) {
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
      case MID_NAVTRACK:
        process_navtrack((void *) sbp, arrival_rtp);
        break;
      case MID_SWVER:
        process_swver((void *) sbp, arrival_rtp);
        break;
      case MID_CLOCKSTATUS:
        process_clk_status((void *) sbp, arrival_rtp);
        break;
      case MID_ACK:
        process_ack((void *) sbp, arrival_rtp);
        break;
      case MID_NACK:
        process_nack((void *) sbp, arrival_rtp);
        break;
      case MID_OTS:
        process_ots((void *) sbp, arrival_rtp);
        break;
      case MID_GEODETIC:
        process_geodetic((void *) sbp, arrival_rtp);
        break;
      case MID_PWR_MODE_RSP:
        process_pwr_rsp((void *) sbp, arrival_rtp);
        break;
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


  event void TxTimer.fired() {
    uint8_t mid;

    switch(gmcb.txq_state) {
      default:
        gps_panic(-1, gmcb.txq_state, 0);
        break;

      case GPSM_TXQ_ACK_WAIT:
        gmcb.txq_retries--;
        if (gmcb.txq_retries == 0) {
          mid = gmcb.txq_mid_ack;
          call CollectEvent.logEvent(DT_EVENT_GPS_NO_ACK, mid, 0, 0, 0);
          txq_adv_restart();
          return;
        }
        /* try sending the original message again */
        gmcb.txq_state = GPSM_TXQ_IDLE;
        txq_start();
        return;
    }
  }


  task void monitor_pwr_task() {
    if (!call GPSPwr.isPowered()) {
      call MinorTimer.stop();
      call MajorTimer.stop();
      major_change_state(GMS_MAJOR_IDLE, MON_EV_PWR_OFF);
      minor_change_state(GMS_OFF, MON_EV_PWR_OFF);
    }
  }

  async event void GPSPwr.pwrOn()  { }

  async event void GPSPwr.pwrOff() {
    post monitor_pwr_task();
  }

  /*
   * Tell McuSleep when we think it is okay to enter DEEPSLEEP.
   * For the GPS Monitor we think DEEPSLEEP is okay if we are IDLE
   * (nothing in particular going on, LPM, MPM, OFF, etc) and if our
   * minor state is OFF, FAIL, or MPM.
   */
  async command mcu_power_t McuPowerOverride.lowestState() {
    if (no_deep_sleep)
      return POWER_SLEEP;
    return POWER_DEEP_SLEEP;
  }


  event void Collect.collectBooted()    { }
  event void GPSControl.gps_shutdown()  { }
  event void GPSControl.standbyDone()   { }
  async event void Panic.hook()         { }
}
