/*
 * Copyright (c) 2016-2017 Eric B. Decker
 * All Rights Reserved
 *
 * typed_data: definitions for typed data on Mass Storage
 * and any Data network packets.  DT, stands for data, typed.
 *
 * MSP432, structures are aligned to a 32 bit boundary (align(4)).
 * Multibyte datums are stored native, little endian.
 *
 * The exact size matters.  The ARM compiler adds padding bytes at the end
 * of structures to round up to an even 32 bit alignment.  We get rid of
 * these pad bytes by using PACKED.  We take pains to set up fields so we
 * do not violate alignment restrictions.  16 bit fields on 2 byte
 * alignment and 32 bit fields on 4 byte alignment.   Structures start on
 * 4 byte alignment.
 *
 * PACKED only eliminates padding within the data fields.  The next
 * dt struct will be aligned on a 32 bit boundary.
 */

#ifndef __TYPED_DATA_H__
#define __TYPED_DATA_H__

#include <stdint.h>
#include <panic.h>
#include <image_info.h>

#ifndef PACKED
#define PACKED __attribute__((__packed__))
#endif

typedef enum {
  DT_TINTRYALF		= 0,            /* next, force next sector */
  DT_CONFIG		= 1,
  DT_SYNC		= 2,
  DT_REBOOT		= 3,		/* reboot sync */
  DT_PANIC		= 4,
  DT_VERSION		= 5,
  DT_EVENT	        = 6,
  DT_DEBUG		= 7,

  DT_GPS_VERSION        = 8,
  DT_GPS_TIME		= 9,
  DT_GPS_GEO		= 10,
  DT_GPS_XYZ            = 11,
  DT_SENSOR_DATA	= 12,
  DT_SENSOR_SET		= 13,
  DT_TEST		= 14,
  DT_NOTE		= 15,

  /*
   * GPS_RAW is used to encapsulate data as received from the GPS.
   */
  DT_GPS_RAW_SIRFBIN	= 16,
  DT_MAX		= 16,
  DT_16                 = 0xffff,       /* force to 2 bytes */
} dtype_t;


#define DT_MAX_HEADER 64

/*
 * In memory and within a SD sector, DT headers are constrained to be 32
 * bit aligned (aligned(4)).  This means that all data must be padded as
 * needed to make the next dt header start on a 4 byte boundary.
 *
 * All records (data blocks, dt headers) start with 2 byte little endian
 * length.  A 2 byte little endian data type field (dtype) and optionally a
 * 32 bit (4 byte) time stamp since last reboot.  Units are ms (we haven't
 * decided yet on whether to make them binary or decimal millisecs).
 *
 * Length is the total size of the data block including header and any
 * following data.  The length does not include any padding at the end of
 * the data block (this would be to make sure the next dt header is quad
 * byte aligned).  When skipping over records one must compensate for any
 * potential padding.  The next header must start on an even 4 byte
 * address.
 *
 * ie.  nxt = (cur + len + 3) & 0xffff_fffc
 *
 * DT_HDR_SIZE_<stuff> defines how large any header is prior to any
 * variable length data.  It is used for redundancy checks.
 *
 * Many dt headers will be followed by variable length data.  The len
 * field in the data block header includes both the header length as
 * well as the variable length data.  There is no padding between the
 * dt header and where the data starts.  There is no assumption made
 * about the alignment of the data.
 *
 * <something>_BLOCK_SIZE is used to say how much data the whole structure
 * needs to take.
 *
 * The special dtype, DT_TINTRYALF, is used to force reading/writing the
 * next sector when a dt header will not fit contiguously into the current
 * sector.  The weird letters mean, This Is Not The Record You Are Looking
 * For, a StarWars play.  It is also sort of pronounceable.  It is used by
 * the Collector, when the header won't fit into the current disk sector.
 * It is only used towards the end of the sector when the header won't fit.
 */

typedef struct {                /* size 4 */
  uint16_t len;
  dtype_t  dtype;
} PACKED dt_header_t;


typedef struct {                /* size 8 */
  uint16_t len;
  dtype_t  dtype;
  uint32_t stamp_ms;
} PACKED dt_header_ts_t;


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
  uint32_t time_cycle;          /* time cycle */
} PACKED dt_sync_t;


typedef struct {
  uint16_t len;                 /* size 14, 0x0E */
  dtype_t  dtype;
  uint32_t stamp_ms;
  uint32_t sync_majik;
  uint32_t time_cycle;          /* time cycle */
  uint16_t boot_count;
} PACKED dt_reboot_t;


typedef struct {
  uint16_t len;                 /* size 27, 0x1A */
  dtype_t  dtype;
  uint32_t stamp_ms;
  parg_t   arg0;
  parg_t   arg1;
  parg_t   arg2;
  parg_t   arg3;
  uint8_t  pcode;               /* from Panic.panic  */
  uint8_t  where;               /* from Panic.panic  */
  uint8_t  index;               /* which panic block */
} PACKED dt_panic_t;


typedef struct {
  uint16_t    len;              /* size 8, 0x08 */
  dtype_t     dtype;
  image_ver_t ver_id;
  hw_ver_t    hw_ver;
} PACKED dt_version_t;


enum {
  DT_EVENT_SURFACED         = 1,
  DT_EVENT_SUBMERGED        = 2,
  DT_EVENT_DOCKED           = 3,
  DT_EVENT_UNDOCKED         = 4,
  DT_EVENT_GPS_BOOT         = 5,
  DT_EVENT_GPS_BOOT_TIME    = 6,
  DT_EVENT_GPS_RECONFIG     = 7,
  DT_EVENT_GPS_START        = 8,
  DT_EVENT_GPS_OFF          = 9,
  DT_EVENT_GPS_FAST         = 10,
  DT_EVENT_GPS_FIRST        = 11,
  DT_EVENT_GPS_SATS_2       = 12,
  DT_EVENT_GPS_SATS_7       = 13,
  DT_EVENT_GPS_SATS_29      = 14,
  DT_EVENT_GPS_CYCLE_TIME   = 15,
  DT_EVENT_GPS_GEO          = 16,
  DT_EVENT_GPS_XYZ          = 17,
  DT_EVENT_GPS_TIME         = 18,
  DT_EVENT_GPS_RX_ERR       = 19,
  DT_EVENT_SSW_DELAY_TIME   = 20,
  DT_EVENT_SSW_BLK_TIME     = 21,
  DT_EVENT_SSW_GRP_TIME     = 22,
};


typedef struct {
  uint16_t len;                 /* size 18, 0x12 */
  dtype_t  dtype;
  uint32_t stamp_ms;
  uint32_t arg0;
  uint32_t arg1;
  uint32_t arg2;
  uint32_t arg3;
  uint16_t ev;
} PACKED dt_event_t;


/*
 * General GPS dt header.
 *
 * Used by:
 *
 *   DT_GPS_VERSION
 *   DT_GPS_RAW_SIRFBIN
 *
 * Note: at one point we thought that we would be able to access the
 * GPS data directly (multi-byte fields).  But we are little endian
 * and the GPS protocol is big-endian.  Buttom line, is we don't worry
 * about alignment when dealing with Raw packets.  The decode has to
 * marshal the data to mess with the big endianess.
 *
 * Originally, we would build extractive typed_data from the underlying
 * GPS sirfbin packets.  This doesn't seem to buy us anything so these
 * extractive data blocks have been nuked.  We always write out the raw
 * GPS data and do what ever processing is needed to obtain the data
 * we need to run internal Tag mechanisms.
 */
typedef struct {
  uint16_t len;                 /* size 13 + var */
  dtype_t  dtype;
  uint32_t stamp_ms;            /* time stamp in ms */
  uint32_t mark_us;             /* mark stamp in usecs (dec) */
  uint8_t  chip_id;
} PACKED dt_gps_t;


/*
 * gps chip ids
 */

enum {
  CHIP_GPS_GSD4E   = 1,
};


typedef struct {
  uint16_t len;                 /* size 14 + var */
  dtype_t  dtype;
  uint32_t stamp_ms;
  uint32_t sched_ms;
  uint16_t sns_id;
} PACKED dt_sensor_data_t;


typedef struct {
  uint16_t len;                 /* size 16 + var */
  dtype_t  dtype;
  uint32_t stamp_ms;
  uint32_t sched_ms;
  uint16_t mask;
  uint16_t mask_id;
} PACKED dt_sensor_set_t;


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
} PACKED dt_note_t;


enum {
  DT_HDR_SIZE_HEADER        = sizeof(dt_header_t),
  DT_HDR_SIZE_HEADER_TS     = sizeof(dt_header_ts_t),
  DT_HDR_SIZE_SYNC          = sizeof(dt_sync_t),
  DT_HDR_SIZE_REBOOT        = sizeof(dt_reboot_t),
  DT_HDR_SIZE_PANIC         = sizeof(dt_panic_t),
  DT_HDR_SIZE_VERSION       = sizeof(dt_version_t),
  DT_HDR_SIZE_EVENT         = sizeof(dt_event_t),
  DT_HDR_SIZE_GPS           = sizeof(dt_gps_t),
  DT_HDR_SIZE_SENSOR_DATA   = sizeof(dt_sensor_data_t),
  DT_HDR_SIZE_SENSOR_SET    = sizeof(dt_sensor_set_t),
  DT_HDR_SIZE_NOTE	    = sizeof(dt_note_t),
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
};

#endif  /* __TYPED_DATA_H__ */
