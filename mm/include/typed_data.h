/*
 * Copyright (c) 2016, Eric B. Decker
 * All Rights Reserved
 *
 * typed_data: definitions for typed data on Mass Storage
 * and any Data network packets.  DT, stands for data typed.
 *
 * MSP430 (using ncc/gcc): the structures are
 * set up to be 2 byte aligned (short alignment) and the structures
 * are filled in completely.  16 bit fields are positioned to be
 * aligned at 16 bit alignment.  Not sure if this matters.
 */

#ifndef __TYPED_DATA_H__
#define __TYPED_DATA_H__

/*
 * keep mig happy.  Each tag typed_data block can be transmitted in an
 * encapsulated AM message packet.  The AM type is AM_MM_DATA.
 */

enum {
  AM_DT_IGNORE		= 0xA1,
  AM_DT_CONFIG		= 0xA1,
  AM_DT_SYNC		= 0xA1,
  AM_DT_SYNC_RESTART	= 0xA1,
  AM_DT_REBOOT		= 0xA1,
  AM_DT_PANIC		= 0xA1,
  AM_DT_GPS_VERSION	= 0xA1,
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
  DT_REBOOT		= 3,		/* reboot sync */
  DT_PANIC		= 4,
  DT_VERSION		= 5,
  DT_EVENT	        = 6,
  DT_DEBUG		= 7,

  DT_GPS_VERSION        = 8,
  DT_GPS_TIME		= 9,
  DT_GPS_POS		= 10,
  DT_SENSOR_DATA	= 11,
  DT_SENSOR_SET		= 12,
  DT_TEST		= 13,
  DT_NOTE		= 14,

  /*
   * GPS_RAW is used to encapsulate data as received from the GPS.
   */
  DT_GPS_RAW		= 15,
  DT_GPS_NMEA_RAW	= 16,
  DT_MAX		= 16,
};


/*
 * All multibyte fields are stored in network order
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
 * If we lose a byte or somehow get out of order (lost sector etc) then
 * we be screwed.  Unless there is some mechanism for resyncing.  The
 * SYNC/REBOOT data block contains a 32 bit majik number that we
 * search for if we get out of sync.  This lets us sync back up to the
 * data stream.
 *
 * The same majik number is written in both data block types so we only
 * have to search for one value when resyncing.  On reboot the dtype
 * is set to REBOOT indicating the reboot.  Every N minutes
 * a sync record is written to minimize how much data is lost if we
 * need to do a resync.
 */

#define SYNC_MAJIK 0xdedf00efUL

typedef nx_struct dt_sync {
  nx_uint16_t len;
  nx_uint8_t  dtype;
  nx_uint32_t stamp_ms;
  nx_uint32_t sync_majik;
} dt_sync_nt;


typedef nx_struct dt_reboot {
  nx_uint16_t len;
  nx_uint8_t  dtype;
  nx_uint32_t stamp_ms;
  nx_uint32_t sync_majik;
  nx_uint16_t boot_count;
} dt_reboot_nt;


typedef nx_struct dt_panic {
  nx_uint16_t len;
  nx_uint8_t  dtype;
  nx_uint32_t stamp_ms;
  nx_uint8_t  pcode;
  nx_uint8_t  where;
  nx_uint16_t arg0;
  nx_uint16_t arg1;
  nx_uint16_t arg2;
  nx_uint16_t arg3;
} dt_panic_nt;

/*
 * gps chip types
 */

enum {
  CHIP_GPS_SIRF3   = 1,
  CHIP_GPS_ORG4472 = 2,
  CHIP_GPS_GSD4E   = 3,
};


typedef nx_struct dt_gps_version {
  nx_uint16_t len;
  nx_uint8_t  dtype;
  nx_uint32_t stamp_ms;
  nx_uint8_t  chip_type;
  nx_uint8_t  gps_version[80];
} dt_gps_version_nt;


/*
 * For Sirf3,   chip_type CHIP_GPS_SIRF3
 * For ORG4472, CHIP_GPS_ORG4472
 * M10478,      CHIP_GPS_GSD4E
 */
typedef nx_struct dt_gps_time {
  nx_uint16_t len;
  nx_uint8_t  dtype;
  nx_uint32_t stamp_ms;
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
 * For ORG4472, CHIP_GPS_ORG4472
 * M10478,      CHIP_GPS_GSD4E
 */
typedef nx_struct dt_gps_pos {
  nx_uint16_t len;
  nx_uint8_t  dtype;
  nx_uint32_t stamp_ms;
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
  nx_uint32_t sched_ms;
  nx_uint32_t stamp_ms;
  nx_uint16_t data[0];
} dt_sensor_data_nt;

typedef nx_struct dt_sensor_set {
  nx_uint16_t      len;
  nx_uint8_t       dtype;
  nx_uint32_t      sched_ms;
  nx_uint32_t      stamp_ms;
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
  nx_uint32_t   stamp_ms;
  nx_uint8_t	data[0];
} dt_gps_raw_nt;

typedef nx_struct dt_gps_nmea_raw {
  nx_uint16_t	len;
  nx_uint8_t	dtype;
  nx_uint8_t	chip;
  nx_uint32_t   stamp_ms;
  nx_uint8_t	data[0];
} dt_gps_nmea_raw_nt;


/*
 * The way the allocation works out is as follows:
 * DT overhead:	len, dtype, chip, stamp: 8 bytes
 * SirfBin overhead: start, len, chksum, stop: 8 bytes
 * max data: 91 bytes (from MID 41, Geodetic)
 *
 * total: 107 bytes.  we round up to 128.
 */

#include "sirbin_msg.h"

typedef nx_struct dt_version {
  nx_uint16_t	len;
  nx_uint8_t	dtype;
  nx_uint8_t	major;
  nx_uint8_t	minor;
  nx_uint8_t	build;
} dt_version_nt;


enum {
  DT_EVENT_SURFACED = 1,
  DT_EVENT_SUBMERGED,
  DT_EVENT_DOCKED,
  DT_EVENT_UNDOCKED,
  DT_EVENT_GPS_BOOT,
  DT_EVENT_GPS_RECONFIG,
  DT_EVENT_GPS_START,
  DT_EVENT_GPS_OFF,
  DT_EVENT_GPS_FAST,
  DT_EVENT_GPS_FIRST,
  DT_EVENT_GPS_SATS_2,
  DT_EVENT_GPS_SATS_7,
  DT_EVENT_GPS_SATS_29,
  DT_EVENT_GPSCM_STATE,
  DT_EVENT_GPS_BOOT_TIME,
  DT_EVENT_GPS_CYCLE_TIME,
  DT_EVENT_SSW_DELAY_TIME,
  DT_EVENT_SSW_BLK_TIME,
  DT_EVENT_SSW_GRP_TIME,
};


typedef nx_struct dt_event {
  nx_uint16_t len;
  nx_uint8_t  dtype;
  nx_uint32_t stamp_ms;
  nx_uint8_t  ev;
  nx_uint16_t arg;
} dt_event_nt;


typedef nx_struct dt_debug {
  nx_uint16_t len;
  nx_uint8_t  dtype;
  nx_uint32_t stamp_ms;
} dt_debug_nt;


enum {
  DT_HDR_SIZE_IGNORE        = sizeof(dt_ignore_nt),
  DT_HDR_SIZE_CONFIG        = sizeof(dt_config_nt),
  DT_HDR_SIZE_SYNC          = sizeof(dt_sync_nt),
  DT_HDR_SIZE_REBOOT        = sizeof(dt_reboot_nt),
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
  GPS_POS_BLOCK_SIZE      = (DT_HDR_SIZE_GPS_POS + GPS_POS_PAYLOAD_SIZE),
};

#endif  /* __TYPED_DATA_H__ */
