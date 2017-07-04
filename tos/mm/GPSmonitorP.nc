/*
 * Copyright (c) 2017 Eric B. Decker
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
 */

/*
 * The GPSmonitor sits on top of the GPS stack and handles interactions.
 *
 * First, it receives any packets coming from the GPS chip.  Note all
 * multibyte datums in the GPS packets are big endian.  We are little
 * endian so must compensate.
 */


#include <TagnetTLV.h>
#include <sirf_msg.h>

#ifndef GPS_COLLECT_RAW
#define GPS_COLLECT_RAW
#endif

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
  uint32_t ts;                          /* last seen time stamp */
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
  uint32_t ts;                          /* last seen time stamp */
  uint32_t drift;
  uint32_t bias;
  uint32_t tow;                         /* reported time of week */
  uint16_t week_x;                      /* extended week */
  uint8_t  nsats;
} gps_clock_t;


/* from MID 41, geodetic data */
typedef struct {
  uint32_t ts;                          /* last seen time stamp */
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
  uint32_t ts;                          /* last seen time stamp */
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
  uint32_t ts;                          /* last seen time stamp */
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


module GPSmonitorP {
  provides interface TagnetAdapter<tagnet_gps_xyz_t> as InfoSensGpsXYZ;
  uses {
    interface GPSReceive;
    interface Collect;
    interface CollectEvent;
    interface Panic;
//    interface Platform;
  }
}
implementation {

  gps_xyz_t  m_xyz;
  gps_geo_t  m_geo;
  gps_time_t m_time;
  gps_1pps_t m_pps;


  command bool InfoSensGpsXYZ.get_value(tagnet_gps_xyz_t *t, uint8_t *l) {
    t->gps_x = m_xyz.x;
    t->gps_y = m_xyz.y;
    t->gps_z = m_xyz.z;
    *l = TN_GPS_XYZ_LEN;
  }


  /*
   * MID 2: NAV_DATA
   */
  void process_navdata(sb_nav_data_t *np, uint32_t arrival_ms) {
    uint8_t pmode;
    uint8_t data[GPS_XYZ_BLOCK_SIZE];
    dt_gps_xyz_t *dxp;
    gps_xyz_t    *mxp;

    nop();
    nop();
    if (!np || CF_BE_16(np->len) != NAVDATA_LEN)
      return;

    call CollectEvent.logEvent(DT_EVENT_GPS_SATS_2, np->nsats, np->mode1);
    pmode = np->mode1 & SB_NAV_M1_PMODE_MASK;
    if (pmode >= SB_NAV_M1_PMODE_SV2KF && pmode <= SB_NAV_M1_PMODE_SVODKF) {
      /*
       * we consider a valid fix anywhere from a 2D (2SV KF fix) to an over
       * determined >= 5 sat fix.
       */
      nop();
      dxp  = (void *) data;
      mxp = &m_xyz;
      mxp->ts    = dxp->stamp_ms = arrival_ms;
      mxp->tow   = dxp->tow      = CF_BE_32(np->tow);
      mxp->week  = dxp->week     = CF_BE_16(np->week);
      mxp->x     = dxp->x        = CF_BE_32(np->xpos);
      mxp->y     = dxp->y        = CF_BE_32(np->ypos);
      mxp->z     = dxp->z        = CF_BE_32(np->zpos);
      mxp->mode1 = dxp->mode1    = np->mode1;
      mxp->hdop  = dxp->hdop     = np->hdop;
      mxp->nsats = dxp->nsats    = np->nsats;

      dxp->len = GPS_XYZ_BLOCK_SIZE;
      dxp->dtype = DT_GPS_XYZ;
      call Collect.collect((void *) dxp, sizeof(*dxp), NULL, 0);
    }
  }


  /*
   * MID 6: SW VERSION/GPS VERSION
   */
  void process_swver(sb_soft_version_data_t *svp, uint32_t arrival_ms) {
    dt_gps_t gps_block;

    nop();
    nop();
    if (!svp) return;
    gps_block.len = svp->len - 1 + sizeof(gps_block);
    gps_block.dtype = DT_GPS_VERSION;
    gps_block.stamp_ms = arrival_ms;
    gps_block.mark_us  = 0;
    gps_block.chip_id = CHIP_GPS_GSD4E;
    call Collect.collect((void *) &gps_block, sizeof(gps_block), svp->data, svp->len - 1);
  }


  /*
   * MID 7: CLOCK_STATUS
   */
  void process_clockstatus(sb_clock_status_data_t *cp, uint32_t arrival_ms) { }


  /*
   * MID 41: GEODETIC_DATA
   * Extract time and position data out of the geodetic gps packet
   */
  void process_geodetic(sb_geodetic_t *gp, uint32_t arrival_ms) {
    uint8_t data[GPS_GEO_BLOCK_SIZE];   /* bigger of GEO or TIME */
    dt_gps_time_t *dtp;
    gps_time_t    *mtp;
    dt_gps_geo_t  *dgp;
    gps_geo_t     *mgp;

    if (!gp || gp->len != GEODETIC_LEN)
      return;

    call CollectEvent.logEvent(DT_EVENT_GPS_SATS_29, gp->nsats, gp->nav_valid);

    if (gp->nav_valid == 0) {
      dtp = (dt_gps_time_t *)data;
      mtp = &m_time;

      dtp->len       = GPS_TIME_BLOCK_SIZE;
      dtp->dtype     = DT_GPS_TIME;
      dtp->chip_id   = CHIP_GPS_GSD4E;

      dtp->stamp_ms  = mtp->ts        = arrival_ms;
      dtp->tow       = mtp->tow       = CF_BE_32(gp->tow);
      dtp->week_x    = mtp->week_x    = CF_BE_16(gp->week_x);
      dtp->nsats     = mtp->nsats     = gp->nsats;

      dtp->utc_year  = mtp->utc_year  = CF_BE_16(gp->utc_year);
      dtp->utc_month = mtp->utc_month = gp->utc_month;
      dtp->utc_day   = mtp->utc_day   = gp->utc_day;
      dtp->utc_hour  = mtp->utc_hour  = gp->utc_hour;
      dtp->utc_min   = mtp->utc_min   = gp->utc_min;
      dtp->utc_ms    = mtp->utc_ms    = CF_BE_16(gp->utc_ms);

      dtp->clock_bias  = CF_BE_32(gp->clock_bias);
      dtp->clock_drift = CF_BE_32(gp->clock_drift);
      call Collect.collect((void *)dtp, GPS_TIME_BLOCK_SIZE, NULL, 0);

      dgp = (dt_gps_geo_t *)data;
      mgp = &m_geo;

      dgp->len       = GPS_GEO_BLOCK_SIZE;
      dgp->dtype     = DT_GPS_GEO;
      dgp->stamp_ms  = mgp->ts        = arrival_ms;
      dgp->tow       = mgp->tow       = CF_BE_32(gp->tow);
      dgp->week_x    = mgp->week_x    = CF_BE_16(gp->week_x);
      dgp->nsats     = mgp->nsats     = gp->nsats;
      dgp->chip_id   = CHIP_GPS_GSD4E;

      dgp->gps_lat   = mgp->lat       = CF_BE_32(gp->lat);
      dgp->gps_long  = mgp->lon       = CF_BE_32(gp->lon);
      dgp->ehpe      = mgp->ehpe      = CF_BE_32(gp->ehpe);
      dgp->hdop      = mgp->hdop      = gp->hdop;
      dgp->sat_mask  = mgp->sat_mask  = CF_BE_32(gp->sat_mask);
      dgp->nav_valid = mgp->nav_valid = CF_BE_16(gp->nav_valid);
      dgp->nav_type  = mgp->nav_type  = CF_BE_16(gp->nav_type);
      call Collect.collect((void *)dgp, GPS_GEO_BLOCK_SIZE, NULL, 0);

      mgp->additional_mode = gp->additional_mode;
      mgp->alt_ell = CF_BE_32(gp->alt_elipsoid);
      mgp->alt_msl = CF_BE_32(gp->alt_msl);
      mgp->sog     = CF_BE_16(gp->sog);
      mgp->cog     = CF_BE_16(gp->cog);
      /* other stuff */
    }
  }


  event void GPSReceive.msg_available(uint8_t *msg, uint16_t len,
        uint32_t arrival_ms, uint32_t mark_j) {
    sb_header_t *sbp;

    sbp = (void *) msg;
    if (sbp->start1 != SIRFBIN_A0 || sbp->start2 != SIRFBIN_A2) {
      call Panic.warn(PANIC_GPS, 134, sbp->start1, sbp->start2, 0, 0);
      return;
    }

#ifdef GPS_COLLECT_RAW
    {
      dt_gps_t hdr;

      hdr.len      = sizeof(hdr) + len;
      hdr.dtype    = DT_GPS_RAW_SIRFBIN;
      hdr.stamp_ms = arrival_ms;
      hdr.mark_us  = (mark_j * MULT_JIFFIES_TO_US) / DIV_JIFFIES_TO_US;
      hdr.chip_id  = CHIP_GPS_GSD4E;
      call Collect.collect((void *) &hdr, sizeof(hdr), msg, len);
    }
#endif

    switch (sbp->mid) {
      case MID_NAVDATA:
	process_navdata((void *) sbp, arrival_ms);
	break;
      case MID_SWVER:
        process_swver((void *) sbp, arrival_ms);
        break;
      case MID_CLOCKSTATUS:
        process_clockstatus((void *) sbp, arrival_ms);
	break;
      case MID_GEODETIC:
        process_geodetic((void *) sbp, arrival_ms);
        break;
      default:
	break;
    }
  }

  async event void Panic.hook() { }

}
