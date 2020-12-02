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
 * The GPSmonitor sits at the top of the GPS stack and handles top level
 * interactions.
 *
 * The lowest level driver handles initial boot, configuration, and
 * collection of packet bytes.  These bytes get handed to the protocol
 * handler where they get buffered by buffer slicing (MsgBuf).  As packets
 * become available they are handed to the GPSmonitor.
 *
 * Packets include multibyte datums which are little endian.  These datums
 * are aligned to the start of the class field.  Storage in MsgBuf is also
 * not guaranteed to be aligned.  Any multibyte access must be done using
 * appropriate access routines that build the datum using byte access
 * only.
 *
 * The low level driver's bootstrap is executed late in the system bootstrap
 * to allow for the SSW (SD stream storage writer) subsystem to be up.  The
 * GPSmonitor doesn't gain control until after the driver bootstrap completes.
 *
 *********
 *
 * Major States
 *
 * SLEEP        sleeping
 * CYCLE        simple fix cycle
 * SATS_COLLECT collecting fixes for almanac and ephemis collection
 * TIME_COLLECT collecting fixes when doing time syncronization
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


#define GPS_ACK_TIMEOUT             1024

#define GPS_MON_MAX_CYCLE_TIME      ( 2 * 60 * 1024)

// 5 mins between last cycle and next cycle
#define GPS_MON_SLEEP               ( 5 * 60 * 1024)


/*
 * Internal Storage types.
 *
 * We hang onto various data from the GPS persistently.
 * These types define what these structures look like.
 * They are instantated in the implementation block.
 */

/* from NAV/POSECEF CID 0101 */
typedef struct {
  rtctime_t    rt;                      /* rtctime - last seen */
  dt_gps_xyz_t dt;
} gps_xyz_t;


typedef struct {
  rtctime_t    rt;                      /* rtctime - last seen */
  uint32_t     itow;
  uint16_t     gdop;
  uint16_t     pdop;
  uint16_t     tdop;
  uint16_t     vdop;
  uint16_t     hdop;
} gps_dop_t;


/* from NAV/CLOCK CID 0122 */
typedef struct {
  rtctime_t    rt;
  dt_gps_clk_t dt;
} gps_clk_t;


/* from NAV/PVT CID 0107 */
typedef struct {
  rtctime_t    rt;                      /* rtctime - last seen */
  dt_gps_geo_t dt;
} gps_geo_t;


/* from NAV/PVT CID 0107 */
typedef struct {
  rtctime_t     rt;                     /* rtctime - last seen */
  dt_gps_time_t dt;
} gps_time_t;


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
  gpsm_major_state_t major_state;           /* monitor major state */
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


module GPSmonitorP {
  provides {
    interface TagnetAdapter<tagnet_gps_xyz_t> as InfoSensGpsXyz;
    interface TagnetAdapter<tagnet_gps_cmd_t> as InfoSensGpsCmd;
    interface McuPowerOverride;
    interface GPSLog;
  } uses {
    interface Boot;                         /* in boot */
    interface GPSControl;
    interface MsgTransmit;
    interface MsgReceive;

    interface Collect;
    interface CollectEvent;
    interface Rtc;
    interface CoreTime;

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
  uint32_t     last_nsats_seen, last_nsats_count;

  /* cycle start, total cycles run and total time both fix found/none */
  uint32_t     cycle_start, ncycles, totaltime;

  /* number fixes found and time consumed taking those fixes */
  uint32_t     fix_count, fix_sum;

  /* number of no fix found and time consumed missing fixes */
  uint32_t     nofix_count, nofix_sum;

#define LAST_NSATS_COUNT_INIT 10

  gps_xyz_t   m_xyz;
  gps_dop_t   m_dop;
  gps_clk_t   m_clk;
  gps_geo_t   m_geo;
  gps_time_t  m_time;

  void gps_warn(uint8_t where, parg_t p, parg_t p1) {
    call Panic.warn(PANIC_GPS, where, p, p1, 0, 0);
  }

  void gps_panic(uint8_t where, parg_t p, parg_t p1) {
    call Panic.panic(PANIC_GPS, where, p, p1, 0, 0);
  }


  const uint16_t ubx_ack_cids[] = { 0 };

  bool ubx_needs_ack(uint16_t clsid) {
    int i;

    for (i = 0; ubx_ack_cids[i]; i++)
      if (clsid == ubx_ack_cids[i]) return TRUE;
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
    call MsgTransmit.send(gps_msg, gps_len);
    return SUCCESS;
  }

  event void MsgTransmit.send_done(error_t result) { }

  error_t txq_enqueue(uint8_t *gps_msg) {
    if (gmcb.txq_len == 0) {            /* empty queue */
      txq[gmcb.txq_head] = gps_msg;
      gmcb.txq_nxt = txq_adv(gmcb.txq_head);
      gmcb.txq_len++;
      return SUCCESS;
    }
    if (gmcb.txq_len >= MAX_GPS_TXQ)
      return EBUSY;
    txq[gmcb.txq_nxt] = gps_msg;
    gmcb.txq_nxt = txq_adv(gmcb.txq_nxt);
    gmcb.txq_len++;
    return SUCCESS;
  }


  /* enqueue and start the queue */
  error_t txq_send(uint8_t *gps_msg) {
    error_t err;

    if ((err = txq_enqueue(gps_msg)) == SUCCESS)
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
        call MsgTransmit.send_abort();
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


  void enqueue_entry_msgs() { }
  void enqueue_exit_msgs()  { }


  void verify_gmcb() {
    if (gmcb.majik_a != GMCB_MAJIK || gmcb.majik_a != GMCB_MAJIK)
      gps_panic(97, (parg_t) &gmcb, 0);
    if (gmcb.major_state > GMS_MAJOR_MAX)
      gps_panic(98, 0, gmcb.major_state);
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
    if (gmcb.major_state == GMS_MAJOR_SLEEP)
      no_deep_sleep = FALSE;
    else
      no_deep_sleep = TRUE;
    if (old_state != new_state) {
      if (old_state <= GMS_MAJOR_SLEEP && new_state >= GMS_MAJOR_CYCLE)
        enqueue_entry_msgs();
      if (new_state <= GMS_MAJOR_SLEEP && old_state >= GMS_MAJOR_CYCLE)
        enqueue_exit_msgs();
    }
  }


  /*
   * We are being told the system has come up.
   *
   * The underlying driver has already done run to completion initilization
   * and has left the gps running.  This is indicated by the return from
   * GPSControl.turnOn()
   *
   * If EALREADY, the gps has been left running, do an acquire/cycle.
   *
   * Otherwise, assume the gps is sleeping and start a sleep cycle.
   */
  event void Boot.booted() {
    error_t rtn;

    gmcb.majik_a = gmcb.majik_b = GMCB_MAJIK;
    major_change_state(GMS_MAJOR_BOOT, MON_EV_BOOT);
    /* instrumentation cells all default to 0 via statup code. */
    call GPSControl.logStats();
    rtn = call GPSControl.turnOn();
    if (rtn == EALREADY) {              /* still running look for fix */
      /* leave in MAJOR_BOOT.  This indicates that we are starting up. */
      ncycles++;
      cycle_start = call MajorTimer.getNow();
      call MajorTimer.startOneShot(GPS_MON_MAX_CYCLE_TIME);
      call CollectEvent.logEvent(DT_EVENT_GPS_CYCLE_START, ncycles, 0, cycle_start, 0);
      txq_start();
    } else {                            /* otherwise just do and SLEEP delay */
      call CollectEvent.logEvent(DT_EVENT_GPS_BOOT_SLEEP, ncycles, 0, cycle_start, 0);
      major_change_state(GMS_MAJOR_SLEEP, MON_EV_BOOT);
      call MajorTimer.startOneShot(GPS_MON_SLEEP);
    }
  }


  command bool InfoSensGpsXyz.get_value(tagnet_gps_xyz_t *t, uint32_t *l) {
    if (!t || !l)
      gps_panic(0, 0, 0);
    t->gps_x = m_xyz.dt.ecefx;
    t->gps_y = m_xyz.dt.ecefy;
    t->gps_z = m_xyz.dt.ecefz;
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
        switch(gmcb.major_state) {
          default:
            gps_panic(137, gmcb.major_state, MON_EV_CYCLE);
            break;

          case GMS_MAJOR_CYCLE:             /* already in cycle */
            break;                          /* ignore request   */

          case GMS_MAJOR_SLEEP:
            call GPSControl.wakeup();
            /* fall through */

          case GMS_MAJOR_SATS_STARTUP:
          case GMS_MAJOR_SATS_COLLECT:
          case GMS_MAJOR_TIME_COLLECT:
            call MajorTimer.startOneShot(GPS_MON_MAX_CYCLE_TIME);
            major_change_state(GMS_MAJOR_CYCLE, MON_EV_CYCLE);
            break;
        }
        break;

      case GDC_STATE:
        major_change_state(gmcb.major_state, MON_EV_STATE_CHK);
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

      case GDC_RESET:
        call GPSControl.reset();
        break;

      case GDC_RAW_TX:
        l = *lenp - 1;                  /* grab the length of the message */
        do {
          if (l > MAX_RAW_TX) {         /* bail if too big */
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


  /*
   * UBX packets show up in blocks that are grouped together.  Packets
   * that are part of the same block will have the same itow value.
   *
   * We look at the PVT packet to determine fix as well as time.  But
   * there are additional status packets associated with the PVT packet
   * that are also interesting.  If a fix has been seen, the status variable
   * fix_seen will be set.
   *
   * Once a fix has been seen, we need to keep collecting to make sure
   * we also collect the status packets.  We use the EOE packet to know
   * when the block is finished.  If fix_seen is set, we will transition
   * back to sleep.
   */
  void process_nav_eoe(void *msg, rtctime_t *rtp) {
    uint32_t delta;
    uint16_t ev;

    if (gmcb.fix_seen) {
      delta = call MajorTimer.getNow() - cycle_start;
      fix_count++;                      /* one more fix seen */
      fix_sum += delta;
      totaltime += delta;
      ev = (gmcb.major_state == GMS_MAJOR_BOOT) ? DT_EVENT_GPS_FIRST_FIX
        : DT_EVENT_GPS_CYCLE_LTFF;
      call CollectEvent.logEvent(ev,                     fix_count,
                delta, fix_sum, fix_sum/fix_count);

      major_change_state(GMS_MAJOR_SLEEP, MON_EV_FIX);
      call GPSControl.standby();
      call CollectEvent.logEvent(DT_EVENT_GPS_CYCLE_END, ncycles,
                delta, totaltime, totaltime/ncycles);
      cycle_start = 0;
      gmcb.msg_count = 0;
      gmcb.fix_seen  = FALSE;
      call MajorTimer.startOneShot(GPS_MON_SLEEP);
    }
  }

  void process_nav_dop(void *msg, rtctime_t *rtp) {
    ubx_nav_dop_t *ndp;
    gps_dop_t     *dp;

    ndp = msg;
    if (!ndp || CF_LE_16(ndp->len) != NAVDOP_LEN)
      return;

    dp = &m_dop;
    call Rtc.copyTime(&dp->rt, rtp);
    dp->itow = CF_BE_32(ndp->iTow);
    dp->gdop = CF_BE_16(ndp->gDop);
    dp->pdop = CF_BE_16(ndp->pDop);
    dp->tdop = CF_BE_16(ndp->tDop);
    dp->vdop = CF_BE_16(ndp->vDop);
    dp->hdop = CF_BE_16(ndp->hDop);
  }


  void process_nav_pvt(void *msg, rtctime_t *rtp) {
    ubx_nav_pvt_t *npp;
    dt_gps_t       gps_block;
    dt_gps_time_t *tp;
    dt_gps_geo_t  *gp;
    uint8_t        flags, num_sats, fixtype;

    uint64_t       epoch;
    uint32_t       cur_secs,   cap_secs,   gps_secs;
    uint32_t       cur_micros, cap_micros;
    rtctime_t      cur_time;
    int32_t        nano;
    rtctime_t      rtc;
    int32_t        delta,   delta1000;
    bool           force,   skew;
    int            timesrc, forcesrc;

    /*
     * fix is denoted by gnssFixOk set in flags (F bit)
     * denotes valid time and valid fix.
     *
     * when logging a fix, we want ...
     *
     * itow, fixtype, numSVs
     * time: year/mo/day-hr:min:sec.ms   tacc
     * fix:  lat long height msl         hacc vacc  pdop
     */

    npp      = msg;                     /* ptr to pvt packet,  input */
    flags    = npp->flags;              /* byte access */
    num_sats = npp->numSV;
    fixtype  = npp->fixType;

    if (last_nsats_count == 0 || num_sats != last_nsats_seen) {
      call CollectEvent.logEvent(DT_EVENT_GPS_SATS, num_sats, fixtype,
                                 flags, 0);
      last_nsats_seen  = num_sats;
      last_nsats_count = LAST_NSATS_COUNT_INIT;
    } else
      last_nsats_count--;

    if (flags & UBX_NAV_PVT_FLAGS_GNSSFIXOK) {
      /*
       * FIXOK says time and lat/long are both valid
       *
       * from pvt packet
       * o extract time, tacc from pvt
       *   the main fields of time in the pvt packet are rounded to the
       *   nearest hundreth of a second, ie +/- 5ms.
       *
       *   nano can have values of -5000000 (-5ms) to 994999999 (~ 995ms).
       *   rather than dealing with any negative correction which can ripple
       *   through all of the time fields, we leave the main fields alone (sec
       *   and above) and zero the nano field.  We set tacc to -1 to indicate
       *   we've done this.  Shouldn't happen very often.
       *
       * o copy time into m_time/dt_gps_time, tacc
       * o copy capture time (rtp) into m_time/rt
       *
       * o extract lat/long, alt, h/vacc, pdop from pvt.
       * o copy into m_geo/dt_gps_geo
       * o copy capture time (rtp) into m_geo/rt
       *
       * o check time vs cur delta, potential reboot.
       */

      gmcb.fix_seen = TRUE;

      tp  = &m_time.dt;                         /* capture to data stream    */
      call Rtc.copyTime(&m_time.rt, rtp);       /* last seen */
      tp->itow      = CF_LE_32(npp->iTow);
      tp->tacc      = CF_LE_32(npp->tAcc);
      tp->utc_ms    = 0;
      tp->utc_year  = CF_LE_16(npp->year);
      tp->utc_month = npp->month;
      tp->utc_day   = npp->day;
      tp->utc_hour  = npp->hour;
      tp->utc_min   = npp->min;
      tp->utc_sec   = npp->sec;
      tp->nsats     = num_sats;
      nano          = CF_LE_32(npp->nano);
      if (nano >= 0) tp->utc_ms  = nano/1000000;
      else tp->tacc = (uint32_t) -1;

      epoch = call Rtc.rtc2epoch(rtp);
      cap_secs   = epoch >> 32;
      cap_micros = epoch & 0xffffffffUL;

      call Rtc.getTime(&cur_time);
      epoch      = call Rtc.rtc2epoch(&cur_time);
      cur_secs   = epoch >> 32;
      cur_micros = epoch & 0xffffffffUL;

      delta = (cur_secs - cap_secs) * 1000000 + (cur_micros - cap_micros);
      tp->capdelta = delta;

      /* build the dt gps header */
      gps_block.len     = sizeof(gps_block) + sizeof(dt_gps_time_t);
      gps_block.dtype   = DT_GPS_TIME;
      gps_block.mark_us = 0;
      gps_block.chip_id = CHIP_GPS_ZOE;
      gps_block.dir     = GPS_DIR_RX;
      gps_block.pad     = 0;
      call Collect.collect((void *) &gps_block, sizeof(gps_block),
                           (void *) tp, sizeof(*tp));

      gp  = &m_geo.dt;                  /* capture to data stream    */
      call Rtc.copyTime(&m_geo.rt, rtp);
      gp->itow    = CF_LE_32(npp->iTow);
      gp->lat     = CF_LE_32(npp->lat);
      gp->lon     = CF_LE_32(npp->lon);
      gp->alt_ell = CF_LE_32(npp->height);
      gp->alt_msl = CF_LE_32(npp->hMSL);
      gp->hacc    = CF_LE_32(npp->hAcc);
      gp->vacc    = CF_LE_32(npp->vAcc);
      gp->pdop    = CF_LE_16(npp->pDop);
      gp->fixtype = fixtype;
      gp->flags   = flags;
      gp->nsats   = num_sats;

      call Rtc.getTime(&cur_time);
      epoch = call Rtc.rtc2epoch(&cur_time);
      cur_secs   = epoch >> 32;
      cur_micros = epoch & 0xffffffffUL;

      delta = (cur_secs - cap_secs) * 1000000 + (cur_micros - cap_micros);
      gp->capdelta = delta;

      /* build the dt gps header */
      gps_block.len   = sizeof(gps_block) + sizeof(dt_gps_geo_t);
      gps_block.dtype = DT_GPS_GEO;

      /* the rest of the header cells are the same as for time */
      call Collect.collect((void *) &gps_block, sizeof(gps_block),
                           (void *) gp, sizeof(*gp));

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
       *    timesrc < GPS (GPS or below) or excessiveSkew.
       *    set timesrc GPS, reboot.
       */
      timesrc     = call OverWatch.getRtcSrc();
      force       = timesrc < RTCSRC_GPS0;
      forcesrc    = RTCSRC_GPS0;
      delta       = 0;
      rtc.year    = tp->utc_year;
      rtc.mon     = tp->utc_month;
      rtc.day     = tp->utc_day;
      rtc.dow     = 0;
      rtc.hr      = tp->utc_hour;
      rtc.min     = tp->utc_min;
      rtc.sec     = tp->utc_sec;
      rtc.sub_sec = call Rtc.micro2subsec(tp->utc_ms * 1000);
      skew        = call CoreTime.excessiveSkew(&rtc,
                                &gps_secs, &cur_secs, &delta1000);
      force       = (force || skew || (timesrc < RTCSRC_GPS));
      forcesrc    = RTCSRC_GPS;
      if (force) {
        call CollectEvent.logEvent(DT_EVENT_TIME_SRC, forcesrc, delta1000,
                                   timesrc, 2);
        call OverWatch.setRtcSrc(forcesrc);
        call Rtc.syncSetTime(&rtc);
        call OverWatch.flush_boot(call OverWatch.getBootMode(),
                                  ORR_TIME_SKEW);
        /* doesn't return from flush_boot */
      }

      if (call OverWatch.getLoggingFlag(OW_LOG_GPS_MISC)) {
        call CollectEvent.logEvent(DT_EVENT_GPS_DELTA, cur_secs, gps_secs,
                                   delta1000, 0);
      }
    }
  }


  bool always_log(uint8_t *msg) {
    ubx_header_t *ubp;
    uint8_t       cls, id;

    if (*msg == '$')                    /* nmea, eh ... */
      return FALSE;
    ubp = (void *) msg;
    if (ubp->sync1 != UBX_SYNC1 || ubp->sync2 != UBX_SYNC2)
      return FALSE;
    cls = ubp->class;
    id  = ubp->id;
    switch (cls) {
      case UBX_CLASS_INF:
      case UBX_CLASS_ACK:
      case UBX_CLASS_CFG:
      case UBX_CLASS_MON:
        return TRUE;
    }
    if (cls != UBX_CLASS_NAV)
      return FALSE;
    switch (id) {
      case UBX_NAV_CLOCK:
      case UBX_NAV_DOP:
      case UBX_NAV_EOE:
      case UBX_NAV_SAT:
      case UBX_NAV_STATUS:
        return TRUE;
    }
    return FALSE;
  }


  command void GPSLog.collect(uint8_t *msg, uint16_t len, uint8_t dir,
                              rtctime_t *rtp) {
    dt_gps_t      hdr;

    if (call OverWatch.getLoggingFlag(OW_LOG_GPS_RAW) || always_log(msg)) {
      /*
       * gps msg eavesdropping.  Log received messages to the dblk
       * stream.
       */
      hdr.len      = sizeof(hdr) + len;
      hdr.dtype    = DT_GPS_RAW;
      if (rtp)
        call Rtc.copyTime(&hdr.rt, rtp);
      else
        call Rtc.getTime(&hdr.rt);
      hdr.mark_us  = 0;                 /* deprecate */
      hdr.chip_id  = (*msg == '$') ? CHIP_GPS_NMEA : CHIP_GPS_ZOE;
      hdr.dir      = dir;
      hdr.pad      = 0;
      call Collect.collect_nots((void *) &hdr, sizeof(hdr), msg, len);
    }
  }


  /*
   * ublox msg_available: new ublox message is available.
   *
   * incoming message.  NMEA or UBX.
   */
  event void MsgReceive.msg_available(uint8_t *msg, uint16_t len,
        rtctime_t *arrival_rtp, uint32_t mark_j) {
    ubx_header_t *ubp;
    uint16_t      cid;

    ubp = (void *) msg;
    do {
      if (*msg == '$')                  /* NMEA packet */
        break;
      if (ubp->sync1 == UBX_SYNC1 && ubp->sync2 == UBX_SYNC2)
        break;                          /* UBX packet */
      call Panic.warn(PANIC_GPS, 134, ubp->sync1, ubp->sync2,
                       (parg_t) msg, len);
    } while (0);

    call GPSLog.collect(msg, len, GPS_DIR_RX, arrival_rtp);

    if (*msg == '$')
      return;

    if (gmcb.major_state == GMS_MAJOR_SLEEP) {
        gps_warn(100, gmcb.major_state, MON_EV_TIMEOUT_MAJOR);
    }

    gmcb.msg_count++;
    cid = ubp->class << 8 | ubp->id;
    switch (cid) {
      case 0x0104: process_nav_dop(ubp, arrival_rtp); break;
      case 0x0107: process_nav_pvt(ubp, arrival_rtp); break;
      case 0x0161: process_nav_eoe(ubp, arrival_rtp); break;
    }
  }


  event void MajorTimer.fired() {
    uint32_t delta;

    switch(gmcb.major_state) {
      default:
        gps_panic(101, gmcb.major_state, MON_EV_TIMEOUT_MAJOR);
        return;

      case GMS_MAJOR_SLEEP:
        ncycles++;
        cycle_start = call MajorTimer.getNow();
        call MajorTimer.startOneShot(GPS_MON_MAX_CYCLE_TIME);
        if (gmcb.msg_count) {           /* should have been zero'd on sleep entry */
          gps_warn(102, gmcb.major_state, gmcb.msg_count);
          gmcb.msg_count = 0;
        }
        major_change_state(GMS_MAJOR_CYCLE, MON_EV_TIMEOUT_MAJOR);
        call CollectEvent.logEvent(DT_EVENT_GPS_CYCLE_START, ncycles, 0, cycle_start, 0);
        call GPSControl.wakeup();
        return;

      case GMS_MAJOR_BOOT:
      case GMS_MAJOR_CYCLE:
      case GMS_MAJOR_SATS_STARTUP:
      case GMS_MAJOR_SATS_COLLECT:
      case GMS_MAJOR_TIME_COLLECT:
        if (!gmcb.msg_count) {
          /* oops.  in cycle but no msgs seen */
          gps_panic(102, gmcb.major_state, MON_EV_TIMEOUT_MAJOR);
        }
        delta = call MajorTimer.getNow() - cycle_start;
        nofix_count++;
        nofix_sum += delta;
        totaltime += delta;

        major_change_state(GMS_MAJOR_SLEEP, MON_EV_TIMEOUT_MAJOR);
        call GPSControl.standby();
        call CollectEvent.logEvent(DT_EVENT_GPS_CYCLE_NONE, nofix_count,
                delta, nofix_sum, nofix_sum/nofix_count);
        call CollectEvent.logEvent(DT_EVENT_GPS_CYCLE_END,  ncycles,
                delta, totaltime, totaltime/ncycles);
        cycle_start = 0;
        gmcb.msg_count = 0;
        gmcb.fix_seen  = FALSE;
        call MajorTimer.startOneShot(GPS_MON_SLEEP);
        return;
    }
  }


  event void TxTimer.fired() {
    uint16_t clsid;

    switch(gmcb.txq_state) {
      default:
        gps_panic(103, gmcb.txq_state, 0);
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
  event void GPSControl.wakeupDone()    { }
  event void GPSControl.gps_booted()    { }
  event void GPSControl.gps_boot_fail() { }
  async event void Panic.hook()         { }
}
