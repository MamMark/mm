/*
 * Copyright (c) 2016-2017 Eric B. Decker
 * All Rights Reserved
 *
 * typed_data: definitions for typed data on Mass Storage
 * and any Data network packets.  DT, stands for data, typed.
 *
 * MSP432, structures are aligned to a 32 bit boundary (align(4)).
 * Multibyte datums are stored native, little endian.  All headers
 * are required to be an even multiple of 32 bits.  quad granular.
 *
 * The exact size matters.  The ARM compiler adds padding bytes at the end
 * of structures to round up to an even 32 bit alignment.  We take pains to
 * set up fields so we do not violate alignment restrictions.  16 bit
 * fields on 2 byte alignment and 32 bit fields on 4 byte alignment.
 * Structures start on 4 byte alignment.
 *
 * The next dt struct will always be aligned on the next 32 bit boundary.
 */

#ifndef __TYPED_DATA_H__
#define __TYPED_DATA_H__

#include <stdint.h>
#include <panic.h>
#include <image_info.h>
#include <overwatch.h>

#ifndef PACKED
#define PACKED __attribute__((__packed__))
#endif

/*
 * identify what revision of the typed_data.h we are using for this build
 *
 * split into two subfields, major and minor.  Major 0 is development of
 * some flavor.  Releases start at Major 1.
 */
#define DT_H_REVISION   0x00000003

typedef enum {
  DT_TINTRYALF		= 0,            /* next, force next sector */
  DT_REBOOT		= 1,		/* reboot sync */
  DT_VERSION		= 2,
  DT_SYNC		= 3,
  DT_PANIC		= 4,
  DT_FLUSH		= 5,
  DT_EVENT	        = 6,
  DT_DEBUG		= 7,

  DT_GPS_VERSION        = 16,
  DT_GPS_TIME		= 17,
  DT_GPS_GEO		= 18,
  DT_GPS_XYZ            = 19,
  DT_SENSOR_DATA	= 20,
  DT_SENSOR_SET		= 21,
  DT_TEST		= 22,
  DT_NOTE		= 23,
  DT_CONFIG		= 24,

  /*
   * GPS_RAW is used to encapsulate data as received from the GPS.
   */
  DT_GPS_RAW_SIRFBIN	= 32,
  DT_MAX		= 32,

  DT_16                 = 0xffff,       /* force to 2 bytes */
} dtype_t;


#define DT_MAX_HEADER 80

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

typedef struct {                /* size 8 */
  uint16_t len;
  dtype_t  dtype;
  uint32_t stamp_ms;
} PACKED dt_header_t;


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
 *
 * The reboot record also has the current ow_control_block written after
 * it.  This will give us the current values about why we rebooted.
 */

#define SYNC_MAJIK 0xdedf00efUL

typedef struct {
  uint16_t len;                 /* size 12, 0x0C */
  dtype_t  dtype;
  uint32_t stamp_ms;
  uint32_t time_cycle;          /* time cycle */
  uint32_t sync_majik;
} PACKED dt_sync_t;


/*
 * reboot record
 * various info, followed by
 *
 * ow_control_block
 */

typedef struct {
  uint16_t len;                 /* size 14, 0x0E */
  dtype_t  dtype;
  uint32_t stamp_ms;
  uint32_t time_cycle;          /* time cycle */
  uint32_t sync_majik;
  uint32_t dt_h_revision;       /* version identifier of typed_data */
} PACKED dt_reboot_t;

typedef struct {
  dt_reboot_t dt_reboot;
  ow_control_block_t dt_owcb;
} PACKED dt_dump_reboot_t;


/* panic warn only uses this */
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
  uint8_t  pad[2];              /* need to be quad granular */
} PACKED dt_panic_t;


/*
 * version record
 *
 * simple version information
 * followed by the entire image_info block
 */
typedef struct {
  uint16_t    len;              /* size   10    +     144      */
  dtype_t     dtype;            /* dt_version_t + image_info_t */
  uint32_t    stamp_ms;
  uint32_t    base;             /* base address of this image */
} PACKED dt_version_t;

typedef struct {
  dt_version_t dt_ver;
  image_info_t dt_image_info;
} dt_dump_version_t;


typedef enum {
  DT_EVENT_SURFACED         = 1,
  DT_EVENT_SUBMERGED        = 2,
  DT_EVENT_DOCKED           = 3,
  DT_EVENT_UNDOCKED         = 4,
  DT_EVENT_GPS_BOOT         = 5,
  DT_EVENT_GPS_BOOT_TIME    = 6,
  DT_EVENT_GPS_RECONFIG     = 7,
  DT_EVENT_GPS_START        = 8,
  DT_EVENT_GPS_OFF          = 9,
  DT_EVENT_GPS_STANDBY      = 10,
  DT_EVENT_GPS_FAST         = 11,
  DT_EVENT_GPS_FIRST        = 12,
  DT_EVENT_GPS_SATS_2       = 13,
  DT_EVENT_GPS_SATS_7       = 14,
  DT_EVENT_GPS_SATS_29      = 15,
  DT_EVENT_GPS_CYCLE_TIME   = 16,
  DT_EVENT_GPS_GEO          = 17,
  DT_EVENT_GPS_XYZ          = 18,
  DT_EVENT_GPS_TIME         = 19,
  DT_EVENT_GPS_RX_ERR       = 20,
  DT_EVENT_SSW_DELAY_TIME   = 21,
  DT_EVENT_SSW_BLK_TIME     = 22,
  DT_EVENT_SSW_GRP_TIME     = 23,
  DT_EVENT_16               = 0xffff,
} dt_event_id_t;


typedef struct {
  uint16_t len;                 /* size 18, 0x12 */
  dtype_t  dtype;
  uint32_t stamp_ms;
  uint32_t arg0;
  uint32_t arg1;
  uint32_t arg2;
  uint32_t arg3;
  dt_event_id_t ev;
  uint8_t  pad[2];              /* quad granular */
} PACKED dt_event_t;


/*
 * gps chip ids
 */

typedef enum {
  CHIP_GPS_GSD4E   = 1,
} gps_chip_id_t;


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
  gps_chip_id_t chip_id;
  uint8_t  dir;                 /* dir, 0 rx from gps, 1 - tx to gps */
  uint8_t  pad[2];              /* quad granular */
} PACKED dt_gps_t;

/* direction setting in dir in dt_gps_t
 *
 * DIR_RX: packet received from the GPS chip
 * DIR_TX: packet sent to the GPS chip
 */
#define GPS_DIR_RX 0
#define GPS_DIR_TX 1


typedef struct {
  uint16_t len;                 /* size 14 + var */
  dtype_t  dtype;
  uint32_t stamp_ms;
  uint32_t sched_ms;
  uint16_t sns_id;
  uint8_t  pad[2];              /* quad granular */
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
  uint32_t stamp_ms;
  uint16_t note_len;
  uint16_t year;
  uint8_t  month;
  uint8_t  day;
  uint8_t  hrs;
  uint8_t  min;
  uint8_t  sec;
  uint8_t  pad[3];
} PACKED dt_note_t;


enum {
  DT_HDR_SIZE_HEADER        = sizeof(dt_header_t),
  DT_HDR_SIZE_REBOOT        = sizeof(dt_reboot_t),
  DT_HDR_SIZE_VERSION       = sizeof(dt_version_t),
  DT_HDR_SIZE_SYNC          = sizeof(dt_sync_t),
  DT_HDR_SIZE_PANIC         = sizeof(dt_panic_t),
  DT_HDR_SIZE_FLUSH         = sizeof(dt_header_t),
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
