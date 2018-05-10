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
 * *** State Machine Description (GMS_)
 *
 * FAIL         we gave up
 * OFF          powered completely off
 * BOOTING      first boot after reboot, establish comm
 * STARTUP      initial startup messages
 * STANDBY      in Standby
 * MPM          running MPM cycles
 * UP           full up, taking readings.
 */


#include <TagnetTLV.h>
#include <sirf_msg.h>
#include <mm_byteswap.h>
#include <sirf_driver.h>
#include <gps_cmd.h>
#include <rtctime.h>

typedef enum {
  GMS_OFF  = 0,                         /* pwr is off */
  GMS_FAIL = 1,
  GMS_BOOTING,
  GMS_STARTUP,
  GMS_STANDBY,
  GMS_UP,
} gpsm_state_t;                         // gps monitor state


#define GPS_MON_SW_VER_TIMEOUT  1024

#ifndef PANIC_GPS
enum {
  __pcode_gps = unique(UQ_PANIC_SUBSYS)
};

#define PANIC_GPS __pcode_gps
#endif


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


typedef enum mpm_state {
  MPM_START_UP = 0,
  MPM_OS_WAIT,
  MPM_SEND_MPM,
  MPM_MPM_WAIT,
  MPM_SEND_CS,
  MPM_CS_WAIT,
  MPM_SLEEPING,
  MPM_GETTING_FIXES,
} mpm_state_t;


module GPSmonitorP {
  provides {
    interface TagnetAdapter<tagnet_gps_xyz_t> as InfoSensGpsXyz;
    interface TagnetAdapter<tagnet_gps_cmd_t> as InfoSensGpsCmd;
  } uses {
    interface Boot;                           /* in boot */
    interface GPSControl;
    interface GPSTransmit;
    interface GPSReceive;

    interface Collect;
    interface CollectEvent;
    interface Rtc;

    interface Timer<TMilli> as MonTimer;
    interface Panic;
    interface OverWatch;
  }
}
implementation {
  gpsm_state_t gps_mon_state;
  uint32_t     gps_boot_try;

  gps_xyz_t  m_xyz;
  gps_geo_t  m_geo;
  gps_time_t m_time;
  gps_1pps_t m_pps;

  void gps_warn(uint8_t where, parg_t p, parg_t p1) {
    call Panic.warn(PANIC_GPS, where, p, p1, 0, 0);
  }

  void gps_panic(uint8_t where, parg_t p, parg_t p1) {
    call Panic.panic(PANIC_GPS, where, p, p1, 0, 0);
  }


  /*
   * We are being told the system has come up.
   * make sure we can communicate with the GPS and that it is
   * the proper state.
   */
  event void Boot.booted() {
    gps_boot_try = 1;
    gps_mon_state = GMS_BOOTING;
    call CollectEvent.logEvent(DT_EVENT_GPS_BOOT, gps_mon_state,
                               gps_boot_try, 0, 0);
    call GPSControl.turnOn();
  }


  event void GPSControl.gps_booted() {
    switch (gps_mon_state) {
      default:
        gps_panic(1, gps_mon_state, 0);
        return;
      case GMS_BOOTING:
        gps_mon_state = GMS_STARTUP;
        gps_boot_try = 1;
        call GPSTransmit.send((void *) sirf_sw_ver, sizeof(sirf_sw_ver));
        call MonTimer.startOneShot(GPS_MON_SW_VER_TIMEOUT);
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
    switch (gps_mon_state) {
      default:
        gps_panic(2, gps_mon_state, 0);
        return;
      case GMS_BOOTING:
        gps_boot_try++;
        switch (gps_boot_try) {
          default:
            gps_panic(3, gps_mon_state, 0);
            gps_mon_state = GMS_FAIL;
            return;

          case 2:
            /* first time didn't work, hit it with a reset and try again. */
            call CollectEvent.logEvent(DT_EVENT_GPS_BOOT, gps_mon_state,
                                       gps_boot_try, 0, 0);
            call GPSControl.reset();
            call GPSControl.turnOn();
            return;

          case 3:
            call CollectEvent.logEvent(DT_EVENT_GPS_BOOT, gps_mon_state,
                                       gps_boot_try, 0, 0);
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


  command bool InfoSensGpsCmd.set_value(tagnet_gps_cmd_t *db, uint32_t *lenp) {
    gps_raw_tx_t *gp;
    error_t err;
    bool    awake;

    /* too weird, too small, ignore it */
    if (!db || !lenp)
      gps_panic(0, 0, 0);               /* no return */

    db->error = SUCCESS;                /* default, ignore */
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
        awake = call GPSControl.awake();
        err   = call GPSTransmit.send((void *) gp->data, *lenp-1);
        call CollectEvent.logEvent(DT_EVENT_GPS_RAW_TX, 999, err, 0, awake);
        break;

      case GDC_HIBERNATE:
        call GPSControl.hibernate();
        break;

      case GDC_WAKE:
        call GPSControl.wake();
        break;

      case GDC_CANNED:
        break;

      case GDC_SLEEP:
        call OverWatch.halt_and_CF();
        break;

      case GDC_PANIC:
        gps_panic(99, 0, 0);
        break;

      case GDC_REBOOT:
        call OverWatch.flush_boot(call OverWatch.getBootMode(), ORR_USER_REQUEST);
        break;

    }
    db->count  = ++gps_cmd_count;
    *lenp = 0;                          /* no returning payload */
    return TRUE;
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

    call CollectEvent.logEvent(DT_EVENT_GPS_SATS_2, np->nsats, np->mode1,
                               0, call GPSControl.awake());
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
    if (gps_mon_state == GMS_STARTUP) {
      gps_mon_state = GMS_UP;
      call MonTimer.stop();
    }
  }


  /*
   * MID 7: CLOCK_STATUS
   */
  void process_clockstatus(sb_clock_status_data_t *cp, rtctime_t *rtp) { }


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
    call CollectEvent.logEvent(DT_EVENT_GPS_SATS_41, gp->nsats, nav_valid,
                               nav_type, call GPSControl.awake());

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
    call CollectEvent.logEvent(DT_EVENT_GPS_MPM, 60, prp->sid, error,
                               call GPSControl.awake());
  }


  event void GPSReceive.msg_available(uint8_t *msg, uint16_t len,
        rtctime_t *arrival_rtp, uint32_t mark_j) {
    sb_header_t *sbp;
    dt_gps_t hdr;

    sbp = (void *) msg;
    if (sbp->start1 != SIRFBIN_A0 || sbp->start2 != SIRFBIN_A2) {
      call Panic.panic(PANIC_GPS, 134, sbp->start1, sbp->start2, 0, 0);
      return;
    }

    hdr.len      = sizeof(hdr) + len;
    hdr.dtype    = DT_GPS_RAW_SIRFBIN;
    call Rtc.copyTime(&hdr.rt, arrival_rtp);
    hdr.mark_us  = (mark_j * MULT_JIFFIES_TO_US) / DIV_JIFFIES_TO_US;
    hdr.chip_id  = CHIP_GPS_GSD4E;
    hdr.dir      = GPS_DIR_RX;
    call Collect.collect_nots((void *) &hdr, sizeof(hdr), msg, len);

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
      case MID_GEODETIC:
        process_geodetic((void *) sbp, arrival_rtp);
        break;
      case MID_HW_CONFIG_REQ:
        process_hw_config_req((void *) sbp, arrival_rtp);
        break;
      default:
        break;
    }
  }


  event void MonTimer.fired() {
    switch (gps_mon_state) {
      default:
        return;
      case GMS_STARTUP:
        call CollectEvent.logEvent(DT_EVENT_GPS_SWVER_TO, gps_boot_try,
                                   0, 0, 0);
        gps_boot_try++;
        if (gps_boot_try > 4) {
          gps_mon_state = GMS_UP;
          return;
        }
        call GPSTransmit.send((void *) sirf_sw_ver, sizeof(sirf_sw_ver));
        call MonTimer.startOneShot(GPS_MON_SW_VER_TIMEOUT);
        return;
    }
  }


  event void GPSTransmit.send_done()    { }
  event void GPSControl.gps_shutdown()  { }
  event void GPSControl.standbyDone()   { }

  async event void Rtc.currentTime(rtctime_t *timep,
                   uint32_t reason_set) { }
  async event void Panic.hook()         { }
}
