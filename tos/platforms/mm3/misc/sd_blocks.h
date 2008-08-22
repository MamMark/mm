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
 * MAC OS (OS X, gcc):
 */

#ifndef __SD_BLOCKS_H__
#define __SD_BLOCKS_H__

/*
 * keep mig happy.  Each tag SD block can be transmitted in an encapsulated
 * mote packet.  The AM type can be AM_MM3_CONTROL, DATA, or DEBUG.
 */
enum {
  AM_MM3_CONTROL	= 0x20,
  AM_MM3_DATA		= 0x21,
  AM_MM3_DEBUG		= 0x22,
  AM_DT_IGNORE		= 0x21,
  AM_DT_CONFIG		= 0x21,
  AM_DT_SYNC		= 0x21,
  AM_DT_SYNC_RESTART	= 0x21,
  AM_DT_PANIC		= 0x21,
  AM_DT_GPS_TIME	= 0x21,
  AM_DT_GPS_POS		= 0x21,
  AM_DT_SENSOR_SET	= 0x21,
  AM_DT_TEST		= 0x21,
  AM_DT_CAL_STRING	= 0x21,
  AM_DT_GPS_RAW		= 0x21,
  AM_DT_VERSION		= 0x21,
  AM_DT_SENSOR_DATA	= 0x21,
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
  DT_CAL_STRING		= 10,

  /*
   * GPS_RAW is used to encapsulate data as received from the GPS.
   */   
  DT_GPS_RAW		= 11,
  DT_VERSION		= 12,
  DT_MAX		= 13,
};


/*
 * All records (data blocks) start with a big (?) endian
 * 2 byte length.  Then the data type field follows
 * defining the rest of the structure.  Length is the
 * total size of the data block including header and
 * any following data.  This is to provide additional
 * redundancy and allows for skipping records if needed.
 * You still have to get lucky.
 *
 * NOTE: For cross compiler compatibility dtype has to be
 * defined as a uint8_t rather than a enum of dtype_t.  GCC
 * makes enums 4 bytes long while IAR makes them what ever
 * size is large enough.
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

typedef nx_struct dt_sync {
  nx_uint16_t len;
  nx_uint8_t  dtype;
  nx_uint32_t stamp_mis;
  nx_uint32_t sync_majik;
} dt_sync_nt;


#define SYNC_MAJIK 0xdedf00ef


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
 * For Sirf3, chip_type DT_GPS_SIRF3
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
 * For Sirf3, chip_type DT_GPS_SIRF3
 */
typedef nx_struct dt_gps_pos {
  nx_uint16_t len;
  nx_uint8_t  dtype;
  nx_uint32_t stamp_mis;
  nx_uint8_t  chip_type;
  nx_uint16_t nav_type;
  nx_uint32_t sats_seen;		/* bit mask, sats in solution */
  nx_uint32_t gps_lat;			/* + North, x 10^7 degrees */
  nx_uint32_t gps_long;			/* + East,  x 10^7 degrees */
  nx_uint8_t  num_svs;			/* number of sv in solution */
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

typedef nx_struct dt_cal_string {
  nx_uint16_t	     len;
  nx_uint8_t	     dtype;
  nx_uint8_t	     sec;
  nx_uint8_t	     min;
  nx_uint8_t	     hrs;
  nx_uint8_t	     day;
  nx_uint8_t	     month;
  nx_uint16_t	     year;
  nx_uint16_t	     cal_string_len;
  nx_uint8_t	     data[0];
} dt_cal_string_nt;

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
 *
 * DT overhead:	len, dtype, chip, stamp: 8 bytes
 * SirfBin overhead: start, len, chksum, stop: 8 bytes
 * max data: 91 bytes (from MID 41, Geodetic)
 *
 * total: 107 bytes.  we round up to 128.
 */


typedef nx_struct dt_version{
  nx_uint16_t	len;
  nx_uint8_t	dtype;
  nx_uint8_t	major;
  nx_uint8_t	minor;
  nx_uint8_t	tweak;
} dt_version_nt;

typedef nx_struct dt_test {
  nx_uint16_t   len;
  nx_uint8_t    dtype;
  nx_uint8_t    data[0];
} dt_test_nt;

enum {
  DT_HDR_SIZE_IGNORE        = sizeof(dt_ignore_nt),
  DT_HDR_SIZE_CONFIG        = sizeof(dt_config_nt),
  DT_HDR_SIZE_SYNC          = sizeof(dt_sync_nt),
  DT_HDR_SIZE_PANIC         = sizeof(dt_panic_nt),
  DT_HDR_SIZE_GPS_TIME      = sizeof(dt_gps_time_nt),
  DT_HDR_SIZE_GPS_POS       = sizeof(dt_gps_pos_nt),
  DT_HDR_SIZE_SENSOR_DATA   = sizeof(dt_sensor_data_nt),
  DT_HDR_SIZE_SENSOR_SET    = sizeof(dt_sensor_set_nt),
  DT_HDR_SIZE_CAL_STRING    = sizeof(dt_cal_string_nt),
  DT_HDR_SIZE_GPS_RAW       = sizeof(dt_gps_raw_nt),
  DT_HDR_SIZE_VERSION       = sizeof(dt_version_nt),
  DT_HDR_SIZE_TEST          = sizeof(dt_test_nt),
};


/*
 * Payload_size is how many bytes are needed in addition to the
 * dt_sensor_data_nt struct.   Block_Size is total bytes used by
 * the dt_sensor_data_nt header and any payload.  Payloads use 2
 * bytes per datam (16 bit values).  <sensor>_BLOCK_SIZE is what
 * needs to allocated.
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
};

#endif  /* __SD_BLOCKS_H__ */
