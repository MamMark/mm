/*
 * Copyright (c) 2020 Eric B. Decker
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
 * multibyte datums in UBX packets are little endian and aligned to
 * the beginning of the buffer.
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
#include <mm_byteswap.h>
#include <ublox_msg.h>
#include <ublox_driver.h>
#include <gps_mon.h>
#include <rtctime.h>

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
  uint16_t           txq_pending_ack;       /* class/id needing acking */
  uint32_t           majik_b;
} gps_monitor_control_t;


/*
 * config msgs end with send swver, which triggers the end of config.
 * at one point we hit the gps chip with a warmstart via msg 128.
 * but this is problematic because the gps processor goes away for
 * a time.  Which complicates getting the swver trigger.
 *
 * We always want msg 7, clk status.  We use this for providing
 * extended gps week values.  Let the gps chip keep track.  If
 * we haven't seen clk_status, we add 2048 to any week value.
 */
const uint8_t *config_msgs[] = {
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
    interface MsgTransmit;
    interface MsgReceive;

    interface Collect;
    interface CollectEvent;
    interface Rtc;
    interface CoreTime;

    interface Timer<TMilli> as MinorTimer;
    interface Timer<TMilli> as MajorTimer;
    interface Timer<TMilli> as TxTimer;
    interface Panic;
    interface OverWatch;
    interface TagnetRadio;
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


  const uint16_t ubx_ack_classids[] = { 0 };

  bool ubx_needs_ack(uint16_t clsid) {
    int i;
//    uint8_t class, id;

//    class = (clsid >> 8) & 0xff;
//    id    = (clsid & 0xff);
    for (i = 0; ubx_ack_classids[i]; i++)
      if (clsid == ubx_ack_classids[i]) return TRUE;
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
    uint8_t * gps_msg;
    uint16_t  gps_len;

    if (gmcb.txq_state != GPSM_TXQ_IDLE)
      return EALREADY;
    if (gmcb.txq_len == 0)
      return EOFF;

    if (gmcb.txq_len >= MAX_GPS_TXQ)
      gps_panic(-1, gmcb.txq_len, 0);

    /*
     * head of the queue is a ublox gps msg.
     *
     * Packet starts with 2 byte SYNC, Class (1), ID (1) and then
     * two bytes of little endian length.
     *
     * But, we don't know if the tx data starts on an aligned address, so we
     * can't use the ubx_header struct.  So we extract the length by hand,
     * remember it is little endian.
     */
    gps_msg = txq[gmcb.txq_head];
    gps_len = gps_msg[5] << 8 | gps_msg[4];
    if (gps_msg[0] != UBX_SYNC1 ||
        gps_msg[1] != UBX_SYNC2 ||
        gps_len > UBX_MAX_MSG)
      gps_panic(-1, gps_msg[0] << 8 | gps_msg[1], gps_len);
    gps_len += UBX_OVERHEAD;            /* add in overhead */
    gmcb.txq_state = GPSM_TXQ_SENDING;
    return call MsgTransmit.send(gps_msg, gps_len);
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
        call MsgTransmit.send_stop();
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


  void txq_adv_restart() {
    gmcb.txq_pending_ack = 0;
    gmcb.txq_head = txq_adv(gmcb.txq_head);
    gmcb.txq_len--;
    gmcb.txq_state = GPSM_TXQ_IDLE;
    txq_start();                        /* fire next one up */
  }


  void enqueue_entry_msgs() {
    /*
     * hint: we get invoked when going into any on state.  But the queue
     * doesn't get fired up until the minor state machine enters collect.
     */
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
    mon_enter_comm_check(ev);
  }


  /*
   * We are being told the system has come up.
   * make sure we can communicate with the GPS and that it is
   * in the proper state.
   *
   * GPSControl.turnOn will always respond either with a
   * GPSControl.gps_booted or gps_boot_fail signal.
   *
   * No need for a timer here.  Any timeout happens in the driver.
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
  };

#define MAX_CANNED 0
#define MAX_RAW_TX 64

  /*
   * The network stack passes in a buffer that has the data we want to send
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
                               0, 0, 0);
    switch (gp->cmd) {
      default:
      case GDC_NOP:
        break;

      case GDC_TURNON:
        err = call GPSControl.turnOn();
        call CollectEvent.logEvent(DT_EVENT_GPS_CMD, gp->cmd, err, 1, 0);
        break;

      case GDC_TURNOFF:
        err = call GPSControl.turnOff();
        call CollectEvent.logEvent(DT_EVENT_GPS_CMD, gp->cmd, err, 1, 0);
        break;

      case GDC_STANDBY:
        err = call GPSControl.standby();
        call CollectEvent.logEvent(DT_EVENT_GPS_CMD, gp->cmd, err, 1, 0);
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
        call TagnetRadio.setHome();
        break;

      case GDC_MON_GO_NEAR:
        call TagnetRadio.setNear();
        break;

      case GDC_MON_GO_LOST:
        call TagnetRadio.setLost();
        break;

      case GDC_AWAKE_STATUS:
        call CollectEvent.logEvent(DT_EVENT_GPS_AWAKE_S, 999, 0, 0, 0);
        break;

      case GDC_MPM:
        break;

      case GDC_PULSE:
        break;

      case GDC_RESET:
        call GPSControl.reset();
        break;

      case GDC_RAW_TX:
        l = *lenp - 1;                  /* grab the length of the message */
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
        call CollectEvent.logEvent(DT_EVENT_GPS_RAW_TX, 999, err, l, 0);
        break;

      case GDC_HIBERNATE:
        call GPSControl.hibernate();
        break;

      case GDC_WAKE:
        call GPSControl.wake();
        break;

      case GDC_CANNED:
        l   = gp->data[0];              /* grab the msg code */
        do {
          if (l > MAX_CANNED) {
            err = EINVAL;
            break;
          }
          err = txq_send((void *) canned_msgs[l]);
        } while (0);
        call CollectEvent.logEvent(DT_EVENT_GPS_CANNED, l, err, l, 0);
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


  event void MsgTransmit.send_done() {
    uint16_t clsid;                     /* class/id */
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
        clsid   = UBX_CLASS_ID(gps_msg);
        if (ubx_needs_ack(clsid)) {
          gmcb.txq_state   = GPSM_TXQ_ACK_WAIT;
          call TxTimer.startOneShot(GPS_ACK_TIMEOUT);

          /* non-zero txq_pending_ack -> ack exchange in progress */
          if (gmcb.txq_pending_ack) return;

          /* first time waiting for ack, set up retries */
          gmcb.txq_pending_ack = clsid;
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
    uint32_t err;

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

        gmcb.msg_count = 0;
        if ((gmcb.retry_count & 1) == 0) {      /* pulse on even */
          call CollectEvent.logEvent(DT_EVENT_GPS_PULSE, gmcb.retry_count,
                                     0, 0, 0);
        }
        call MinorTimer.startOneShot(GPS_MON_SWVER_TO);
        return;

      case GMS_COMM_CHECK:
        if (gmcb.retry_count < 6) {
          /*
           * Didn't hear anything, pulse and listen for LONG TO
           */
          gmcb.retry_count++;
          minor_change_state(GMS_COMM_CHECK, MON_EV_TIMEOUT_MINOR);
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
        err = 0;
        call CollectEvent.logEvent(DT_EVENT_GPS_MPM, 100, err, 0, 0);
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
  }

  void mon_ev_msg() {
    uint32_t err;

    gmcb.msg_count++;
    switch(gmcb.minor_state) {
      default:
        return;

      case GMS_COMM_CHECK:
        if (gmcb.major_state == GMS_MAJOR_IDLE) {
          /*
           * Major indicates we want to quiese the GPS.
           */

          /*
           * Not using MPM, just pulse it off
           */
          minor_change_state(GMS_LPM_WAIT, MON_EV_MSG);
          gmcb.retry_count = 0;
          err = 0;

          /* should get a OTS-no back. */
          call CollectEvent.logEvent(DT_EVENT_GPS_MPM, 101, err, 0, 0);
          call MinorTimer.startOneShot(GPS_MON_LPM_RSP_TO);
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
  }

  void mon_ev_ots_yes()  {
  }

  void mon_ev_fix(mon_event_t ev) {
    gmcb.fix_seen = TRUE;
    major_event(ev);
  }

  /* low pwr (mpm) attempted, and got a good response */
  void mon_ev_lpm() {
  }

  /* bad response from mpm */
  void mon_ev_lpm_error() {
  }


  /*
   * Monitor State Machine
   */
  void minor_event(mon_event_t ev) {
    verify_gmcb();
    switch(ev) {
      default:
        gps_panic(100, gmcb.minor_state, ev);

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


  uint16_t gps_extend_week(uint16_t week10) {
    if (m_clk.dt.week_x != 0)
      return m_clk.dt.week_x;
    else
      return week10 + 2048;
  }


  /*
   * MID 2: NAV_DATA
   */
  void process_navdata(void *np, rtctime_t *rtp) {
#ifdef notdef
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
                                 0, 0);
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
      xdtp->week_x = gps_extend_week(CF_BE_16(np->week10));
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
#endif
  }


  /*
   * MID 4: Nav Track
   */
  void process_navtrack(void *tp, rtctime_t *rtp) {
#ifdef notdef
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
    tdtp->week_x = gps_extend_week(CF_BE_16(tp->week10));
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
#endif
  }


  void process_swver(void *svp, rtctime_t *rtp) { }

  void process_clk_status(void *csp, rtctime_t *rtp) { }

  void process_geodetic(void *gp, rtctime_t *rtp) { }


  void process_default(ubx_header_t *ubp, rtctime_t *rtp) {
    if (!ubp || !rtp)
      return;
  }


  event void MsgReceive.msg_available(uint8_t *msg, uint16_t len,
        rtctime_t *arrival_rtp, uint32_t mark_j) {
    ubx_header_t *ubp;
    dt_gps_t hdr;

    ubp = (void *) msg;
    if (ubp->sync1 != UBX_SYNC1 || ubp->sync2 != UBX_SYNC2) {
      call Panic.warn(PANIC_GPS, 134, ubp->sync1, ubp->sync2,
                       (parg_t) msg, len);
      return;
    }

    if (call OverWatch.getLoggingFlag(OW_LOG_GPS_RAW)) {
      /*
       * gps msg eavesdropping.  Log received messages to the dblk
       * stream.
       */
      hdr.len      = sizeof(hdr) + len;
      hdr.dtype    = DT_GPS_RAW;
      call Rtc.copyTime(&hdr.rt, arrival_rtp);
      hdr.mark_us  = (mark_j * MULT_JIFFIES_TO_US) / DIV_JIFFIES_TO_US;
      hdr.chip_id  = CHIP_GPS_ZOE;
      hdr.dir      = GPS_DIR_RX;
      call Collect.collect_nots((void *) &hdr, sizeof(hdr), msg, len);
    }

    minor_event(MON_EV_MSG);
  }


  event void MinorTimer.fired() {
    minor_event(MON_EV_TIMEOUT_MINOR);
  }

  event void MajorTimer.fired() {
    major_event(MON_EV_TIMEOUT_MAJOR);
  }


  event void TxTimer.fired() {
    uint16_t clsid;

    switch(gmcb.txq_state) {
      default:
        gps_panic(-1, gmcb.txq_state, 0);
        break;

      case GPSM_TXQ_ACK_WAIT:
        gmcb.txq_retries--;
        if (gmcb.txq_retries == 0) {
          clsid = gmcb.txq_pending_ack;
          call CollectEvent.logEvent(DT_EVENT_GPS_NO_ACK, clsid, 0, 0, 0);
          txq_adv_restart();
          return;
        }
        /* try sending the original message again */
        gmcb.txq_state = GPSM_TXQ_IDLE;
        txq_start();
        return;
    }
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
