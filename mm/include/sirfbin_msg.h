#ifndef __SIRFBIN_MSG_H__
#define __SIRFBIN_MSG_H__

/* MID 2, Nav Data */
typedef nx_struct gps_nav_data {
  nx_uint8_t   start1;
  nx_uint8_t   start2;
  nx_uint16_t  len;
  nx_uint8_t   id;
  nx_int32_t   xpos;
  nx_int32_t   ypos;
  nx_int32_t   zpos;
  nx_int16_t   xvel;
  nx_int16_t   yvel;
  nx_int16_t   zvel;
  nx_uint8_t   mode1;
  nx_uint8_t   hdop;
  nx_uint8_t   mode2;
  nx_uint16_t  week;
  nx_uint32_t  tow;
  nx_uint8_t   sats;
  nx_uint8_t   data[0];
} gps_nav_data_nt;

/* MID 4, Tracker Data */
typedef nx_struct gps_tracker_data {
  nx_uint8_t   start1;
  nx_uint8_t   start2;
  nx_uint16_t  len;
  nx_uint8_t   id;
  nx_uint16_t  week;
  nx_uint32_t  tow;
  nx_uint8_t   chans;
  nx_uint8_t   data[0];
} gps_tracker_data_nt;

/* MID 6, s/w version */
typedef nx_struct gps_soft_version_data {
  nx_uint8_t   start1;
  nx_uint8_t   start2;
  nx_uint16_t  len;
  nx_uint8_t   id;
  nx_uint8_t   data[0];
} gps_soft_version_data_nt;

/* MID 7, clock status */
typedef nx_struct gps_clock_status_data {
  nx_uint8_t   start1;
  nx_uint8_t   start2;
  nx_uint16_t  len;
  nx_uint8_t   id;
  nx_uint16_t  week;
  nx_uint32_t  tow;
  nx_uint8_t   sats;
  nx_uint32_t  drift;
  nx_uint32_t  bias;
  nx_uint32_t  gpstime;
} gps_clock_status_data_nt;

/* MID 10, error data */
typedef nx_struct gps_error_data {
  nx_uint8_t   start1;
  nx_uint8_t   start2;
  nx_uint16_t  len;
  nx_uint8_t   id;
  nx_uint16_t  submsg;
  nx_uint16_t  count;
  nx_uint8_t   data[0];
} gps_error_data_nt;

/* MID 14, almanac data */
typedef nx_struct gps_almanac_status_data {
  nx_uint8_t   start1;
  nx_uint8_t   start2;
  nx_uint16_t  len;
  nx_uint8_t   id;
  nx_uint8_t   satid;
  nx_uint16_t  weekstatus;
  nx_uint8_t  data[0];
} gps_almanac_status_data_nt;


/* MID 28, nav lib data */
typedef nx_struct gps_nav_lib_data {
  nx_uint8_t   start1;
  nx_uint8_t   start2;
  nx_uint16_t  len;
  nx_uint8_t   id;
  nx_uint8_t   chan;
  nx_uint32_t  time_tag;
  nx_uint8_t   sat_id;
  nx_uint64_t  soft_time;
  nx_uint64_t  psdo_range;
  nx_uint32_t  car_freq;
  nx_uint64_t  car_phase;
  nx_uint16_t  time_in_track;
  nx_uint8_t   sync_flags;
  nx_uint8_t   c_no_1;
  nx_uint8_t   c_no_2;
  nx_uint8_t   c_no_3;
  nx_uint8_t   c_no_4;
  nx_uint8_t   c_no_5;
  nx_uint8_t   c_no_6;
  nx_uint8_t   c_no_7;
  nx_uint8_t   c_no_8;
  nx_uint8_t   c_no_9;
  nx_uint8_t   c_no_10;
  nx_uint16_t  delta_range_intv;
  nx_uint16_t  mean_delta_time_range;
  nx_uint16_t  extrap_time;
  nx_uint8_t   phase_err_cnt;
  nx_uint8_t   low_pow_cnt;
} gps_nav_lib_data_nt;

/* MID 41, geodetic data */
typedef nx_struct gps_geodetic {
  nx_uint8_t   start1;
  nx_uint8_t   start2;
  nx_uint16_t  len;
  nx_uint8_t   id;
  nx_uint16_t  nav_valid;
  nx_uint16_t  nav_type;
  nx_uint16_t  week;
  nx_uint32_t  tow;			/* seconds x 1e3 */
  nx_uint16_t  utc_year;
  nx_uint8_t   utc_month;
  nx_uint8_t   utc_day;
  nx_uint8_t   utc_hour;
  nx_uint8_t   utc_min;
  nx_uint16_t  utc_sec;			/* x 1e3 (millisecs) */
  nx_uint32_t  sat_mask;
  nx_int32_t   lat;
  nx_int32_t   lon;
  nx_int32_t   alt_elipsoid;
  nx_int32_t   alt_msl;
  nx_uint8_t   map_datum;
  nx_uint16_t  sog;
  nx_uint16_t  cog;
  nx_uint16_t  mag_var;
  nx_int16_t   climb;
  nx_int16_t   heading_rate;
  nx_uint32_t  ehpe;
  nx_uint32_t  evpe;
  nx_uint32_t  ete;
  nx_uint16_t  ehve;
  nx_int32_t   clock_bias;
  nx_int32_t   clock_bias_err;
  nx_int32_t   clock_drift;
  nx_int32_t   clock_drift_err;
  nx_uint32_t  distance;
  nx_uint16_t  distance_err;
  nx_uint16_t  head_err;
  nx_uint8_t   num_svs;
  nx_uint8_t   hdop;
  nx_uint8_t   mode;
} gps_geodetic_nt;

/* MID 52, 1PPS data */
typedef nx_struct gps_pps_data {
  nx_uint8_t   start1;
  nx_uint8_t   start2;
  nx_uint16_t  len;
  nx_uint8_t   id;
  nx_uint8_t   hr;
  nx_uint8_t   min;
  nx_uint8_t   sec;
  nx_uint8_t   day;
  nx_uint8_t   mo;
  nx_uint16_t  year;
  nx_uint16_t  utcintoff;
  nx_uint32_t  utcfracoff;
  nx_uint8_t   status;
  nx_uint32_t  reserved;
} gps_pps_data_nt;


/* MID 255, Dev Data */
typedef nx_struct gps_dev_data {
  nx_uint8_t   start1;
  nx_uint8_t   start2;
  nx_uint16_t  len;
  nx_uint8_t   id;
  nx_uint8_t   data[0];
} gps_dev_data_nt;

#endif  /* __SIRFBIN_MSG_H__ */
