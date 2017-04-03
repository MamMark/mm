/*
 * Copyright (c) 2016-2017 Eric B. Decker
 * All Rights Reserved
 *
 * typed_data: definitions for typed data on Mass Storage
 * and any Data network packets.  DT, stands for data, typed.
 *
 * MSP432, structures are aligned to a 32 bit boundary (align(4)).
 * Multibyte datums are stored native, little endian.
 */

#ifndef __TYPED_DATA_H__
#define __TYPED_DATA_H__

typedef enum {
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
  DT_GPS_RAW_SIRFBIN	= 15,
  DT_GPS_RAW_NMEA	= 16,
  DT_MAX		= 16,
  DT_16                 = 0xffff,       /* force to 2 bytes */
} dtype_t;


/*
 * In memory and within a SD sector, DT headers should start on a 4 byte
 * boundary (aligned(4)).  This means that all data must be padded as
 * needed to make the next header start on a 4 byte boundary.
 *
 * All records (data blocks) start with 2 byte little endian length.  A 2
 * byte little endian data type field (dtype) and optionally a 32 bit (4
 * byte) time stamp since last reboot.  Units are mis (binary millisecs).
 *
 * Length is the total size of the data block including header and any
 * following data.  The length does not include any padding at the end of
 * the data block.  When skipping over records one must compensate for any
 * potential padding.  The next header must start on an even 4 byte
 * address.
 *
 * ie.  nxt = (cur + len + 3) & 0xffff_fffc
 *
 * DT_HDR_SIZE_<stuff> defines how large any header is prior to any
 * variable length data.  It is used for redundancy checks.
 *
 * Many of the data blocks defined below use data[0].  This indicates that
 * data is variable in length.  When using these structures the correct
 * size must be allocated (usually on the stack since we don't use malloc)
 * and then the structure is cast to a dt_<type>_t pointer.
 *
 * <something>_BLOCK_SIZE is used to say how much data the whole structure
 * needs to take.
 */

typedef struct {
  uint16_t len;
  dtype_t  dtype;
} dt_header_t;

typedef struct {
  uint16_t len;
  dtype_t  dtype;
  uint8_t  data[0];
} dt_config_t;


/*
 * SYNCing:
 *
 * Data written to the SD card is a byte stream of typed data records.  If
 * we lose a byte or somehow get out of order (lost sector etc) and we need
 * a mechanism for resyncing.  The SYNC/REBOOT data block contains a 32 bit
 * majik number that we search for if we get out of sync.  This lets us
 * sync back up to the data stream.
 *
 * The same majik number is written in both the SYNC and REBOOT data blocks
 * so we only have to search for one value when resyncing.  On reboot the
 * dtype is set to REBOOT indicating the reboot.  Every N minutes a sync
 * record is written to minimize how much data is lost if we need to do a
 * resync.
 */

#define SYNC_MAJIK 0xdedf00efUL

typedef struct {
  uint16_t len;                 /* size 12, 0x0C */
  dtype_t  dtype;
  uint32_t stamp_ms;
  uint32_t sync_majik;
} dt_sync_t;


typedef struct {
  uint16_t len;                 /* size 14, 0x0E */
  dtype_t  dtype;
  uint32_t stamp_ms;
  uint32_t sync_majik;
  uint16_t boot_count;
} dt_reboot_t;


typedef struct {
  uint16_t len;                 /* size 26, 0x1A */
  dtype_t  dtype;
  uint32_t stamp_ms;
  parg_t   arg0;
  parg_t   arg1;
  parg_t   arg2;
  parg_t   arg3;
  uint8_t  pcode;
  uint8_t  where;
} dt_panic_t;


/*
 * gps chip types
 */

enum {
  CHIP_GPS_SIRF3   = 1,
  CHIP_GPS_ORG4472 = 2,
  CHIP_GPS_GSD4E   = 3,
};


typedef struct {
  uint16_t len;                 /* size 9 + var */
  dtype_t  dtype;
  uint32_t stamp_ms;
  uint8_t  chip_type;
  uint8_t  gps_version[0];
} dt_gps_version_t;


/*
 * For Sirf3,   chip_type CHIP_GPS_SIRF3
 * For ORG4472, CHIP_GPS_ORG4472
 * M10478,      CHIP_GPS_GSD4E
 */
typedef struct {
  uint16_t len;                 /* size 26, 0x1A */
  dtype_t  dtype;
  uint32_t stamp_ms;
  uint32_t clock_bias;		/* m x 10^2 */
  uint32_t clock_drift;		/* m/s x 10^2 */
  uint8_t  chip_type;
  uint8_t  num_svs;
  uint16_t utc_year;
  uint8_t  utc_month;
  uint8_t  utc_day;
  uint8_t  utc_hour;
  uint8_t  utc_min;
  uint16_t utc_millsec;
} dt_gps_time_t;


/*
 * For Sirf3, chip_type CHIP_GPS_SIRF3
 * For ORG4472, CHIP_GPS_ORG4472
 * M10478,      CHIP_GPS_GSD4E
 */
typedef struct {
  uint16_t len;                 /* size 32, 0x20 */
  dtype_t  dtype;
  uint32_t stamp_ms;
  uint8_t  chip_type;
  uint8_t  num_svs;             /* number of sv in solution */
  uint16_t nav_type;
  uint32_t sats_seen;           /* bit mask, sats in solution */
  int32_t  gps_lat;             /* + North, x 10^7 degrees */
  int32_t  gps_long;            /* + East,  x 10^7 degrees */
  uint32_t ehpe;                /* estimated horz pos err, 1e2 */
  uint32_t hdop;                /* err *5 */
} dt_gps_pos_t;

typedef struct {
  uint16_t len;                 /* size 14 + var */
  dtype_t  dtype;
  uint32_t stamp_ms;
  uint32_t sched_ms;
  uint16_t sns_id;
  uint16_t data[0];
} dt_sensor_data_t;

typedef struct {
  uint16_t len;                 /* size 16 + var */
  dtype_t  dtype;
  uint32_t stamp_ms;
  uint32_t sched_ms;
  uint16_t mask;
  uint16_t mask_id;
  uint16_t data[0];
} dt_sensor_set_t;

typedef struct {
  uint16_t len;                 /* size 8 + var */
  dtype_t  dtype;
  uint32_t stamp_ms;
  uint8_t  data[0];
} dt_test_t;


/*
 * Note
 *
 * arbritrary ascii string sent from the base station with a time stamp.
 * one use is when calibrating the device.  Can also be used to add notes
 * about conditions the tag is being placed in.
 *
 * Note (data in the structure) itself is a NULL terminated string.  Len
 * includes the null.
 */
typedef struct {
  uint16_t len;                 /* size 13 + var */
  dtype_t  dtype;
  uint16_t note_len;
  uint16_t year;
  uint8_t  month;
  uint8_t  day;
  uint8_t  hrs;
  uint8_t  min;
  uint8_t  sec;
  uint8_t  data[0];
} dt_note_t;


/*
 * gps raw, message as seen from the gps.
 *
 * could be raw nmea, or raw sirfbin, dtype tells the difference
 * see above for chip definition.
 */

typedef struct {
  uint16_t len;                 /* size 9 + var */
  dtype_t  dtype;
  uint32_t stamp_ms;
  uint8_t  chip;
  uint8_t  data[0];
} dt_gps_raw_t;


typedef struct {
  uint16_t len;                 /* size 7, 0x07 */
  dtype_t  dtype;
  uint8_t  major;
  uint8_t  minor;
  uint8_t  build;
} dt_version_t;


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


typedef struct {
  uint16_t len;                 /* size 12, 0x0c */
  dtype_t  dtype;
  uint32_t stamp_ms;
  uint16_t ev;
  uint16_t arg;
} dt_event_t;


typedef struct {
  uint16_t len;                 /* size 8, 0x08 */
  dtype_t  dtype;
  uint32_t stamp_ms;
} dt_debug_t;


enum {
  DT_HDR_SIZE_HEADER        = sizeof(dt_header_t),
  DT_HDR_SIZE_CONFIG        = sizeof(dt_config_t),
  DT_HDR_SIZE_SYNC          = sizeof(dt_sync_t),
  DT_HDR_SIZE_REBOOT        = sizeof(dt_reboot_t),
  DT_HDR_SIZE_PANIC         = sizeof(dt_panic_t),
  DT_HDR_SIZE_GPS_TIME      = sizeof(dt_gps_time_t),
  DT_HDR_SIZE_GPS_POS       = sizeof(dt_gps_pos_t),
  DT_HDR_SIZE_SENSOR_DATA   = sizeof(dt_sensor_data_t),
  DT_HDR_SIZE_SENSOR_SET    = sizeof(dt_sensor_set_t),
  DT_HDR_SIZE_TEST          = sizeof(dt_test_t),
  DT_HDR_SIZE_NOTE	    = sizeof(dt_note_t),
  DT_HDR_SIZE_GPS_RAW       = sizeof(dt_gps_raw_t),
  DT_HDR_SIZE_VERSION       = sizeof(dt_version_t),
  DT_HDR_SIZE_EVENT	    = sizeof(dt_event_t),
  DT_HDR_SIZE_DEBUG	    = sizeof(dt_debug_t),
};


/*
 * Payload_size is how many bytes are needed in addition to the
 * dt_sensor_data_t struct.   Block_Size is total bytes used by
 * the dt_sensor_data_t header and any payload.  Payloads use 2
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
