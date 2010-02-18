/*
 * sd_blocks: definitions for typed data on Mass Storage
 *
 * This file must be portable.  It is used across multiple
 * machines.
 *
 * MSP430 (using ncc/gcc): the structures are
 * set up to be 2 byte aligned (short alignment) and the structures
 * are filled in completely.  16 bit fields are positioned to be
 * aligned at 16 bit alignment.
 *
 * x86 (under Linux and gcc):
 *
 * MAC OS (OS X, gcc): mactels ae little endian while powermacs are big.
 */

#ifndef __SD_BLOCKS_H__
#define __SD_BLOCKS_H__

/*
 * keep mig happy.  Each tag SD block can be transmitted in an encapsulated
 * mote packet.  The AM type can be AM_MM_CONTROL, DATA, or DEBUG.
 *
 * Place the AM code into the unreserved block.  Formerly we were 0x2x,
 * move this to 0xAx.
 */
enum {
  AM_MM_CONTROL		= 0xA0,
  AM_MM_DATA		= 0xA1,
  AM_MM_DEBUG		= 0xA2,

  AM_DT_IGNORE		= 0xA1,
  AM_DT_CONFIG		= 0xA1,
  AM_DT_SYNC		= 0xA1,
  AM_DT_SYNC_RESTART	= 0xA1,
  AM_DT_PANIC		= 0xA1,
  AM_DT_GPS_TIME	= 0xA1,
  AM_DT_GPS_POS		= 0xA1,
  AM_DT_SENSOR_DATA	= 0xA1,
  AM_DT_SENSOR_SET	= 0xA1,
  AM_DT_TEST		= 0xA1,
  AM_DT_NOTE		= 0xA1,
  AM_DT_GPS_RAW		= 0xA1,
  AM_GPS_NAV_DATA	= 0xA1,
  AM_GPS_TRACKER_DATA	= 0xA1,
  AM_GPS_SOFT_VERSION_DATA
			= 0xA1,
  AM_GPS_ERROR_DATA	= 0xA1,
  AM_GPS_GEODETIC	= 0xA1,
  AM_GPS_PPS_DATA	= 0xA1,
  AM_GPS_CLOCK_STATUS_DATA
			= 0xA1,
  AM_GPS_ALMANAC_STATUS_DATA
			= 0xA1,
  AM_GPS_NAV_LIB_DATA   = 0xA1,
  AM_GPS_DEV_DATA	= 0xA1,
  AM_GPS_UNK		= 0xA1,
  AM_DT_VERSION		= 0xA1,
  AM_DT_EVENT		= 0xA1,
  AM_DT_DEBUG		= 0xA1,
};

enum {
  DT_IGNORE		= 0,
  DT_CONFIG		= 1,
  DT_SYNC		= 2,
  DT_SYNC_RESTART	= 3,
  DT_PANIC		= 4,
  DT_GPS_TIME		= 5,
  DT_GPS_POS		= 6,
  DT_SENSOR_DATA	= 7,
  DT_SENSOR_SET		= 8,
  DT_TEST		= 9,
  DT_NOTE		= 10,

  /*
   * GPS_RAW is used to encapsulate data as received from the GPS.
   */   
  DT_GPS_RAW		= 11,
  DT_VERSION		= 12,
  DT_EVENT	        = 13,
  DT_DEBUG		= 14,
  DT_MAX		= 15,
};


/*
 * All record multibyte fields are stored in network order
 * which is big endian.
 *
 * All records (data blocks) start with a big endian
 * 2 byte length.  Then the data type field follows
 * defining the rest of the structure.  Length is the
 * total size of the data block including header and
 * any following data.  This is to provide additional
 * redundancy and allows for skipping records if needed.
 * You still have to get lucky.
 *
 * DT_HDR_SIZE_<stuff> defines how large any header is
 * prior to variable length data.  It is used for redundancy
 * checks.
 *
 * Many of the data blocks defined below use data[0].  This
 * indicates that data is variable in length.  When using
 * these structures the correct size must be allocated (usually
 * on the stack since we don't use malloc) and then the structure
 * is cast to a dt_<type>_nt pointer.  <something>_BLOCK_SIZE is
 * used to say how much data the whole structure needs to take.
 */

typedef nx_struct dt_ignore {
  nx_uint16_t len;
  nx_uint8_t  dtype;
} dt_ignore_nt;

typedef nx_struct dt_config {
  nx_uint16_t len;
  nx_uint8_t  dtype;
  nx_uint8_t  data[0];
} dt_config_nt;

/*
 * SYNCing:
 *
 * Data written to the SD card is a byte stream of typed data records.
 * If we lose a byte or somehow get out order (lost sector etc) then
 * we be screwed.  Unless there is some mechanism for resyncing.  The
 * SYNC/SYNC_RESTART data block contains a 32 bit majik number that we
 * search for if we get out of sync.  This lets us sync back up to the
 * data stream.
 *
 * The same majik number is written in both data block types so we only
 * have to search for one value when resyncing.  On reboot the dtype
 * is set to SYNC_RESTART indicating the reboot.  Every N minutes
 * a sync record is written to minimize how much data is lost if we
 * need to do a resync.
 */

#define SYNC_MAJIK 0xdedf00ef

typedef nx_struct dt_sync {
  nx_uint16_t len;
  nx_uint8_t  dtype;
  nx_uint32_t stamp_mis;
  nx_uint32_t sync_majik;
} dt_sync_nt;


typedef nx_struct dt_panic {
  nx_uint16_t len;
  nx_uint8_t  dtype;
  nx_uint32_t stamp_mis;
  nx_uint8_t  pcode;
  nx_uint8_t  where;
  nx_uint16_t arg0;
  nx_uint16_t arg1;
  nx_uint16_t arg2;
  nx_uint16_t arg3;
} dt_panic_nt;

/*
 * Currently defined for SIRF chipset.  chip_type 1
 */

enum {
  CHIP_GPS_SIRF3 = 1,
};


/*
 * For Sirf3, chip_type CHIP_GPS_SIRF3
 */
typedef nx_struct dt_gps_time {
  nx_uint16_t len;
  nx_uint8_t  dtype;
  nx_uint32_t stamp_mis;
  nx_uint8_t  chip_type;
  nx_uint8_t  num_svs;
  nx_uint16_t utc_year;
  nx_uint8_t  utc_month;
  nx_uint8_t  utc_day;
  nx_uint8_t  utc_hour;
  nx_uint8_t  utc_min;
  nx_uint16_t utc_millsec;
  nx_uint32_t clock_bias;		/* m x 10^2 */
  nx_uint32_t clock_drift;		/* m/s x 10^2 */
} dt_gps_time_nt;


/*
 * For Sirf3, chip_type CHIP_GPS_SIRF3
 */
typedef nx_struct dt_gps_pos {
  nx_uint16_t len;
  nx_uint8_t  dtype;
  nx_uint32_t stamp_mis;
  nx_uint8_t  chip_type;
  nx_uint16_t nav_type;
  nx_uint8_t  num_svs;			/* number of sv in solution */
  nx_uint32_t sats_seen;		/* bit mask, sats in solution */
  nx_int32_t  gps_lat;			/* + North, x 10^7 degrees */
  nx_int32_t  gps_long;			/* + East,  x 10^7 degrees */
  nx_uint32_t ehpe;			/* estimated horz pos err, 1e2 */
  nx_uint8_t  hdop;			/* err *5 */
} dt_gps_pos_nt;

typedef nx_struct dt_sensor_data {
  nx_uint16_t len;
  nx_uint8_t  dtype;
  nx_uint8_t  sns_id;
  nx_uint32_t sched_mis;
  nx_uint32_t stamp_mis;
  nx_uint16_t data[0];
} dt_sensor_data_nt;

typedef nx_struct dt_sensor_set {
  nx_uint16_t      len;
  nx_uint8_t       dtype;
  nx_uint32_t      sched_mis;
  nx_uint32_t      stamp_mis;
  nx_uint16_t      mask;
  nx_uint8_t       mask_id;
  nx_uint16_t      data[0];
} dt_sensor_set_nt;

typedef nx_struct dt_test {
  nx_uint16_t   len;
  nx_uint8_t    dtype;
  nx_uint8_t    data[0];
} dt_test_nt;

/*
 * Note
 *
 * arbritrary ascii string sent from the base station with a time stamp.
 * one use is when calibrating the device.  Can also be used to add notes
 * about conditions the tag is being placed in.
 *
 * Note (data in the structure) itself is a NULL terminated string.
 */
typedef nx_struct dt_note {
  nx_uint16_t	     len;
  nx_uint8_t	     dtype;
  nx_uint16_t	     year;
  nx_uint8_t	     month;
  nx_uint8_t	     day;
  nx_uint8_t	     hrs;
  nx_uint8_t	     min;
  nx_uint8_t	     sec;
  nx_uint16_t	     note_len;
  nx_uint8_t	     data[0];
} dt_note_nt;

/*
 * see above for chip definition.
 */
typedef nx_struct dt_gps_raw {
  nx_uint16_t	len;
  nx_uint8_t	dtype;
  nx_uint8_t	chip;
  nx_uint32_t   stamp_mis;
  nx_uint8_t	data[0];
} dt_gps_raw_nt;

/*
 * The way the allocation works out is as follows:
 * DT overhead:	len, dtype, chip, stamp: 8 bytes
 * SirfBin overhead: start, len, chksum, stop: 8 bytes
 * max data: 91 bytes (from MID 41, Geodetic)
 *
 * total: 107 bytes.  we round up to 128.
 */



/*
 * Not data types. Sub fields of raw
 * gps data. Defining them to use tos
 * tools. They are sirf output messages.
 */

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

typedef nx_struct gps_soft_version_data {
  nx_uint8_t   start1;
  nx_uint8_t   start2;
  nx_uint16_t  len;
  nx_uint8_t   id;
  nx_uint8_t   data[0];
} gps_soft_version_data_nt;

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

typedef nx_struct gps_error_data {
  nx_uint8_t   start1;
  nx_uint8_t   start2;
  nx_uint16_t  len;
  nx_uint8_t   id;
  nx_uint16_t  submsg;
  nx_uint16_t  count;
  nx_uint8_t   data[0];
} gps_error_data_nt;

typedef nx_struct gps_almanac_status_data {
  nx_uint8_t   start1;
  nx_uint8_t   start2;
  nx_uint16_t  len;
  nx_uint8_t   id;
  nx_uint8_t   satid;
  nx_uint16_t  weekstatus;
  nx_uint8_t  data[0];
} gps_almanac_status_data_nt;


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


typedef nx_struct gps_dev_data {
  nx_uint8_t   start1;
  nx_uint8_t   start2;
  nx_uint16_t  len;
  nx_uint8_t   id;
  nx_uint8_t   data[0];
} gps_dev_data_nt;


typedef nx_struct gps_unk {
  nx_uint8_t   start1;
  nx_uint8_t   start2;
  nx_uint16_t  len;
  nx_uint8_t   id;
  nx_uint8_t   data[0];
} gps_unk_nt;


typedef nx_struct dt_version {
  nx_uint16_t	len;
  nx_uint8_t	dtype;
  nx_uint8_t	major;
  nx_uint8_t	minor;
  nx_uint8_t	tweak;
} dt_version_nt;


enum {
  DT_EVENT_SURFACED = 1,
  DT_EVENT_SUBMERGED,
  DT_EVENT_DOCKED,
  DT_EVENT_UNDOCKED,
  DT_EVENT_GPS_BOOT,
  DT_EVENT_GPS_RECONFIG,
  DT_EVENT_GPS_START,
  DT_EVENT_GPS_GRANT,
  DT_EVENT_GPS_RELEASE,
  DT_EVENT_GPS_OFF,
  DT_EVENT_GPS_FAST,
  DT_EVENT_GPS_FIRST,
  DT_EVENT_GPS_SATS_2,
  DT_EVENT_GPS_SATS_7,
  DT_EVENT_GPS_SATS_29,
  DT_EVENT_GPSCM_STATE,
  DT_EVENT_GPS_BOOT_TIME,
  DT_EVENT_GPS_HOLD_TIME,
  DT_EVENT_SSW_DELAY_TIME,
  DT_EVENT_SSW_BLK_TIME,
  DT_EVENT_SSW_GRP_TIME,
};


typedef nx_struct dt_event {
  nx_uint16_t len;
  nx_uint8_t  dtype;
  nx_uint32_t stamp_mis;
  nx_uint8_t  ev;
  nx_uint16_t arg;
} dt_event_nt;


typedef nx_struct dt_debug {
  nx_uint16_t len;
  nx_uint8_t  dtype;
  nx_uint32_t stamp_mis;
} dt_debug_nt;


enum {
  DT_HDR_SIZE_IGNORE        = sizeof(dt_ignore_nt),
  DT_HDR_SIZE_CONFIG        = sizeof(dt_config_nt),
  DT_HDR_SIZE_SYNC          = sizeof(dt_sync_nt),
  DT_HDR_SIZE_PANIC         = sizeof(dt_panic_nt),
  DT_HDR_SIZE_GPS_TIME      = sizeof(dt_gps_time_nt),
  DT_HDR_SIZE_GPS_POS       = sizeof(dt_gps_pos_nt),
  DT_HDR_SIZE_SENSOR_DATA   = sizeof(dt_sensor_data_nt),
  DT_HDR_SIZE_SENSOR_SET    = sizeof(dt_sensor_set_nt),
  DT_HDR_SIZE_TEST          = sizeof(dt_test_nt),
  DT_HDR_SIZE_NOTE	    = sizeof(dt_note_nt),
  DT_HDR_SIZE_GPS_RAW       = sizeof(dt_gps_raw_nt),
  DT_HDR_SIZE_VERSION       = sizeof(dt_version_nt),
  DT_HDR_SIZE_EVENT	    = sizeof(dt_event_nt),
  DT_HDR_SIZE_DEBUG	    = sizeof(dt_debug_nt),
};


/*
 * Payload_size is how many bytes are needed in addition to the
 * dt_sensor_data_nt struct.   Block_Size is total bytes used by
 * the dt_sensor_data_nt header and any payload.  Payloads use 2
 * bytes per datam (16 bit values).  <sensor>_BLOCK_SIZE is what
 * needs to allocated. Note thet GPS position and time have no
 * payload. All fields ares specified.
 */
 
enum {
  BATT_PAYLOAD_SIZE   = 2,
  BATT_BLOCK_SIZE     = (DT_HDR_SIZE_SENSOR_DATA + BATT_PAYLOAD_SIZE),

  TEMP_PAYLOAD_SIZE   = 2,
  TEMP_BLOCK_SIZE     = (DT_HDR_SIZE_SENSOR_DATA + TEMP_PAYLOAD_SIZE),

  SAL_PAYLOAD_SIZE    = 4,
  SAL_BLOCK_SIZE      = (DT_HDR_SIZE_SENSOR_DATA + SAL_PAYLOAD_SIZE),

  ACCEL_PAYLOAD_SIZE  = 6,
  ACCEL_BLOCK_SIZE    = (DT_HDR_SIZE_SENSOR_DATA + ACCEL_PAYLOAD_SIZE),

  PTEMP_PAYLOAD_SIZE  = 2,
  PTEMP_BLOCK_SIZE    = (DT_HDR_SIZE_SENSOR_DATA + PTEMP_PAYLOAD_SIZE),

  PRESS_PAYLOAD_SIZE  = 2,
  PRESS_BLOCK_SIZE    = (DT_HDR_SIZE_SENSOR_DATA + PRESS_PAYLOAD_SIZE),

  SPEED_PAYLOAD_SIZE  = 4,
  SPEED_BLOCK_SIZE    = (DT_HDR_SIZE_SENSOR_DATA + SPEED_PAYLOAD_SIZE),

  MAG_PAYLOAD_SIZE    = 6,
  MAG_BLOCK_SIZE      = (DT_HDR_SIZE_SENSOR_DATA + MAG_PAYLOAD_SIZE),

  GPS_TIME_PAYLOAD_SIZE   = 0,
  GPS_TIME_BLOCK_SIZE     = (DT_HDR_SIZE_GPS_TIME + GPS_TIME_PAYLOAD_SIZE),

  GPS_POS_PAYLOAD_SIZE    = 0,
  GPS_POS_BLOCK_SIZE      = (DT_HDR_SIZE_GPS_TIME + GPS_POS_PAYLOAD_SIZE),
};

#endif  /* __SD_BLOCKS_H__ */
