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

//#include "sensor_config.h"

//#define PACKED __attribute__((__packed__))
#define PACKED

enum {
    DT_IGNORE		= 0,
    DT_CONFIG		= 1,
    DT_SYNC		= 2,
    DT_SYNC_RESTART	= 3,
    DT_PANIC		= 4,
    DT_GPS_TIME		= 5,
    DT_GPS_POS		= 6,
    DT_SENSOR_DATA	= 7,
    DT_SENSOR_SET	= 8,
    DT_TEST		= 9,
    DT_CAL_STRING	= 10,

    /*
     * GPS_RAW is used to encapsulate data as
     * received from the GPS.  It is used for
     * debugging the GPS
     */   
    DT_GPS_RAW		= 11,
    DT_VERSION		= 12,
    DT_MAX		= 13,
};


/*
 * All records (data blocks) start with a little endian
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
 */

typedef nx_struct {
    nx_uint16_t len;
    nx_uint8_t  dtype;
    nx_uint8_t  fill;
} dt_ignore_pt;

#define DT_HDR_SIZE_IGNORE 4


typedef nx_struct {
    nx_uint16_t len;
    nx_uint8_t  dtype;
    nx_uint8_t  fill;
    nx_uint8_t  data[0];
} dt_config_pt;

#define DT_HDR_SIZE_CONFIG 4


typedef nx_struct {
    nx_uint16_t len;
    nx_uint8_t  dtype;
    nx_uint8_t  fill;
    nx_uint8_t  stamp_epoch;
    nx_uint32_t stamp_mis;
    nx_uint32_t sync_majik;
} PACKED dt_sync_pt;

#define DT_HDR_SIZE_SYNC 14
#define SYNC_MAJIK		0xdedf00ef
#define SYNC_RESTART_MAJIK	0xdaffd00f


//typedef uint32_t gps_time_t;		/* actually a single float */
//typedef uint16_t gps_week_t;		/* actually int16 */
//typedef uint32_t gps_offset_t;

typedef nx_struct {
    nx_uint16_t len;
    nx_uint8_t  dtype;
    nx_uint8_t  fill;
    nx_uint8_t  stamp_epoch;
    nx_uint32_t stamp_mis;
    nx_uint32_t gps_tow;		/* little endian, single float */
    nx_uint16_t gps_week;		/* little endian, uint16_t */
    nx_uint32_t gps_offset;		/* little endian, single float */
} PACKED dt_gps_time_pt;

#define DT_HDR_SIZE_GPS_TIME 20


//typedef uint32_t gps_latlong_t;		/* actually a single precision float */

typedef nx_struct {
    nx_uint16_t len;
    nx_uint8_t  dtype;
    nx_uint8_t  fill;
    nx_uint8_t  stamp_epoch;
    nx_uint32_t stamp_mis;
    nx_uint32_t gps_lat;		/* little endian, single float */
    nx_uint32_t gps_long;		/* little endian, single float */
} PACKED dt_gps_pos_pt;

#define DT_HDR_SIZE_GPS_POS 18


typedef nx_struct {
    nx_uint16_t len;
    nx_uint8_t  dtype;
    nx_uint8_t  id;
    nx_uint8_t  sched_epoch;
    nx_uint32_t sched_mis;
    nx_uint8_t  stamp_epoch;
    nx_uint32_t stamp_mis;
    nx_uint16_t data[0];	/* still 16 bit aligned */
} PACKED dt_sensor_data_nt;

#define DT_HDR_SIZE_SENSOR_DATA 16


/*
 * Payload_size is how many bytes needed in addition to the dt_nx_uint16_t
 * struct.   Block_Size is total bytes used by the dt_sensor_data header
 * and any payload.  Payloads use 2 bytes per datam (16 bit values).
 */

#define BATT_PAYLOAD_SIZE 2
#define BATT_BLOCK_SIZE (sizeof(dt_sensor_data_nt) + BATT_PAYLOAD_SIZE)

#define TEMP_PAYLOAD_SIZE 2
#define TEMP_BLOCK_SIZE (sizeof(dt_sensor_data_pt) + TEMP_PAYLOAD_SIZE)

#define SAL_PAYLOAD_SIZE 4
#define SAL_BLOCK_SIZE (sizeof(dt_sensor_data_pt) + SAL_PAYLOAD_SIZE)

#define ACCEL_PAYLOAD_SIZE 6
#define ACCEL_BLOCK_SIZE (sizeof(dt_sensor_data_pt) + ACCEL_PAYLOAD_SIZE)

#define PRESS_PAYLOAD_SIZE 4
#define PRESS_BLOCK_SIZE (sizeof(dt_sensor_data_pt) + PRESS_PAYLOAD_SIZE)

#define SPEED_PAYLOAD_SIZE 4
#define SPEED_BLOCK_SIZE (sizeof(dt_sensor_data_pt) + SPEED_PAYLOAD_SIZE)

#define MAG_PAYLOAD_SIZE 6
#define MAG_BLOCK_SIZE (sizeof(dt_sensor_data_pt) + MAG_PAYLOAD_SIZE)


typedef struct {
    nx_uint16_t	     len;
    nx_uint8_t	     dtype;
    nx_uint8_t	     fill;
    nx_uint8_t       sched_epoch;
    nx_uint32_t      sched_mis;
    nx_uint8_t       stamp_epoch;
    nx_uint32_t      stamp_mis;
    nx_uint16_t      mask;
    nx_uint8_t       mask_id;
    nx_uint8_t	     fill_a;
    nx_uint16_t      data[0];
} dt_sensor_set_pt;


typedef struct {
    nx_uint16_t	     len;
    nx_uint8_t	     dtype;
    nx_uint8_t	     data[0];
} dt_test_pt;


typedef struct {
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
} PACKED dt_cal_string_pt;


typedef struct {
    nx_uint16_t	len;
    nx_uint8_t	dtype;
    nx_uint8_t  stamp_epoch;
    nx_uint32_t stamp_mis;
    nx_uint8_t	data[0];
} PACKED dt_gps_raw_pt;

#define DT_HDR_SIZE_GPS_RAW 10


typedef struct {
    nx_uint16_t	len;
    nx_uint8_t	dtype;
    nx_uint8_t	major;
    nx_uint8_t	minor;
    nx_uint8_t	tweak;
} PACKED dt_version_pt;

#define DT_HDR_SIZE_VERSION 6


#endif  /* __SD_BLOCKS_H__ */
