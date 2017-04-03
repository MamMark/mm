#ifndef __SIRFBIN_MSG_H__
#define __SIRFBIN_MSG_H__

#ifndef PACKED
#define PACKED __attribute__((__packed__))
#endif

/* MID 2, Nav Data */
typedef struct {
  uint8_t   start1;
  uint8_t   start2;
  uint16_t  len;
  uint8_t   id;
  int32_t   xpos;
  int32_t   ypos;
  int32_t   zpos;
  int16_t   xvel;
  int16_t   yvel;
  int16_t   zvel;
  uint8_t   mode1;
  uint8_t   hdop;
  uint8_t   mode2;
  uint16_t  week;
  uint32_t  tow;
  uint8_t   sats;
  uint8_t   data[0];
} PACKED sb_nav_data_t;

/* MID 4, Tracker Data */
typedef struct {
  uint8_t   start1;
  uint8_t   start2;
  uint16_t  len;
  uint8_t   id;
  uint16_t  week;
  uint32_t  tow;
  uint8_t   chans;
  uint8_t   data[0];
} PACKED sb_tracker_data_t;

/* MID 6, s/w version */
typedef struct {
  uint8_t   start1;
  uint8_t   start2;
  uint16_t  len;
  uint8_t   id;
  uint8_t   data[0];
} PACKED sb_soft_version_data_t;

/* MID 7, clock status */
typedef struct {
  uint8_t   start1;
  uint8_t   start2;
  uint16_t  len;
  uint8_t   id;
  uint16_t  week;
  uint32_t  tow;
  uint8_t   sats;
  uint32_t  drift;
  uint32_t  bias;
  uint32_t  gpstime;
} PACKED sb_clock_status_data_t;

/* MID 10, error data */
typedef struct {
  uint8_t   start1;
  uint8_t   start2;
  uint16_t  len;
  uint8_t   id;
  uint16_t  submsg;
  uint16_t  count;
  uint8_t   data[0];
} PACKED sb_error_data_t;

/* MID 14, almanac data */
typedef struct {
  uint8_t   start1;
  uint8_t   start2;
  uint16_t  len;
  uint8_t   id;
  uint8_t   satid;
  uint16_t  weekstatus;
  uint8_t  data[0];
} PACKED sb_almanac_status_data_t;


/* MID 28, nav lib data */
typedef struct {
  uint8_t   start1;
  uint8_t   start2;
  uint16_t  len;
  uint8_t   id;
  uint8_t   chan;
  uint32_t  time_tag;
  uint8_t   sat_id;
  uint64_t  soft_time;
  uint64_t  psdo_range;
  uint32_t  car_freq;
  uint64_t  car_phase;
  uint16_t  time_in_track;
  uint8_t   sync_flags;
  uint8_t   c_no_1;
  uint8_t   c_no_2;
  uint8_t   c_no_3;
  uint8_t   c_no_4;
  uint8_t   c_no_5;
  uint8_t   c_no_6;
  uint8_t   c_no_7;
  uint8_t   c_no_8;
  uint8_t   c_no_9;
  uint8_t   c_no_10;
  uint16_t  delta_range_intv;
  uint16_t  mean_delta_time_range;
  uint16_t  extrap_time;
  uint8_t   phase_err_cnt;
  uint8_t   low_pow_cnt;
} PACKED sb_nav_lib_data_t;

/* MID 41, geodetic data */
typedef struct {
  uint8_t   start1;
  uint8_t   start2;
  uint16_t  len;
  uint8_t   id;
  uint16_t  nav_valid;
  uint16_t  nav_type;
  uint16_t  week;
  uint32_t  tow;			/* seconds x 1e3 */
  uint16_t  utc_year;
  uint8_t   utc_month;
  uint8_t   utc_day;
  uint8_t   utc_hour;
  uint8_t   utc_min;
  uint16_t  utc_sec;			/* x 1e3 (millisecs) */
  uint32_t  sat_mask;
  int32_t   lat;
  int32_t   lon;
  int32_t   alt_elipsoid;
  int32_t   alt_msl;
  uint8_t   map_datum;
  uint16_t  sog;
  uint16_t  cog;
  uint16_t  mag_var;
  int16_t   climb;
  int16_t   heading_rate;
  uint32_t  ehpe;
  uint32_t  evpe;
  uint32_t  ete;
  uint16_t  ehve;
  int32_t   clock_bias;
  int32_t   clock_bias_err;
  int32_t   clock_drift;
  int32_t   clock_drift_err;
  uint32_t  distance;
  uint16_t  distance_err;
  uint16_t  head_err;
  uint8_t   num_svs;
  uint8_t   hdop;
  uint8_t   mode;
} PACKED sb_geodetic_t;

/* MID 52, 1PPS data */
typedef struct {
  uint8_t   start1;
  uint8_t   start2;
  uint16_t  len;
  uint8_t   mid;
  uint8_t   hr;
  uint8_t   min;
  uint8_t   sec;
  uint8_t   day;
  uint8_t   mo;
  uint16_t  year;
  uint16_t  utcintoff;
  uint32_t  utcfracoff;
  uint8_t   status;
  uint32_t  reserved;
} PACKED sb_pps_data_t;


typedef struct {
  uint8_t   start1;
  uint8_t   start2;
  uint16_t  len;
  uint8_t   mid;
  uint8_t   data[0];
} PACKED sb_header_t;

#endif  /* __SIRFBIN_MSG_H__ */
