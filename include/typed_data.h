/*
 * Copyright (c) 2016-2018 Eric B. Decker, Daniel J. Maltbie
 * All rights reserved.
 *
 * This program is free software: you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation, either version 3 of the License, or
 * any later version.
 *
 * This program is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU General Public License for more details.
 *
 * You should have received a copy of the GNU General Public License
 * along with this program.  If not, see <https://www.gnu.org/licenses/>.
 * See COPYING in the top level directory of this source tree.
 *
 * Contact: Eric B. Decker <cire831@gmail.com>
 *          Daniel J. Maltbie <dmaltbie@danome.com>
 */

#ifndef __TYPED_DATA_H__
#define __TYPED_DATA_H__

#include <stdint.h>
#include <core_rev.h>
#include <panic.h>
#include <image_info.h>
#include <overwatch.h>
#include <rtctime.h>

#ifndef PACKED
#define PACKED __attribute__((__packed__))
#endif

/************************************************************************
 *
 * Configuration Stuff
 *
 ************************************************************************/

/*
 * Sync records are used to make sure we can always find the data stream if
 * we ever lose sync.  We lay down a sync record every SYNC_MAX_SECTORS
 * sectors (see below) or as a fail safe after SYNC_PERIOD time goes by.
 *
 * SYNC_MAX_SECTORS also determines where DBlkManager starts looking
 * for the last written SYNC on a restart.
 */

/*
 * 5 min * 60 sec/min * 1024 ticks/sec
 * Tmilli is binary
 */
#define SYNC_PERIOD         (5UL * 60 * 1024)
#define SYNC_MAX_SECTORS    8


/************************************************************************
 *
 * Data Block identifiers (dtype, record types, rtypes)
 *
 */

typedef enum {
  DT_NONE		= 0,
  DT_REBOOT		= 1,		/* reboot sync */
  DT_VERSION		= 2,
  DT_SYNC		= 3,
  DT_EVENT              = 4,
  DT_DEBUG		= 5,
  DT_SYNC_FLUSH         = 6,

  DT_GPS_VERSION        = 16,
  DT_GPS_TIME		= 17,
  DT_GPS_GEO		= 18,
  DT_GPS_XYZ            = 19,
  DT_SENSOR_DATA	= 20,
  DT_SENSOR_SET		= 21,
  DT_TEST		= 22,
  DT_NOTE		= 23,
  DT_CONFIG		= 24,
  DT_GPS_PROTO_STATS    = 25,

  /*
   * GPS_RAW is used to encapsulate data as received from the GPS.
   */
  DT_GPS_RAW_SIRFBIN	= 32,
  DT_TAGNET             = 33,
  DT_MAX		= 33,

  DT_16                 = 0xffff,       /* force to 2 bytes */
} dtype_t;


#define DT_MAX_HEADER 80
#define DT_MAX_RLEN   1024

/*
 * In memory and within a SD sector, DT headers are constrained to be 32
 * bit aligned (aligned(4)).  This means that all data must be padded as
 * needed to make the next dt header start on a 4 byte boundary.
 * Additionally, headers are quad granular as well.  This allows the
 * data layout to also start out quad aligned.
 *
 * All records (data blocks, dt headers) start with a 2 byte little endian
 * length, a 2 byte little endian data type field (dtype), a 4 byte little
 * endian record number, and a 10 byte rtctime stamp.  RtcTime is 10 bytes,
 * year.mon.day.dow.hr.min.sec.sub_sec.  The header also includes a record
 * checksum (recsum).  This is a 16 bit little endian checksum over
 * individual bytes in both the header and data areas.
 *
 * A following dt_header is required to be quad aligned.  There will 0-3
 * pad bytes following a record.  Length does not include these pad bytes.
 * We want the length field (len) to maintain fidility with respect to the
 * header and payload length.
 *
 * Length is the total size of the data block including header and any
 * following payload.  The next dblock is required to start on the next
 * quad alignment.  This requires 0-3 pad bytes which is not reflected
 * in the length field.  The next header must start on an even 4 byte
 * address.
 *
 * ie.  nxt_ptr = (cur_ptr + len + 3) & 0xffff_fffc
 */

typedef struct {                /* size 20 */
  uint16_t len;
  dtype_t  dtype;               /* 2 bytes */
  uint32_t recnum;
  rtctime_t rt;                 /* 10 byte rtctime */
  uint16_t recsum;
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
 * dtype is set to REBOOT indicating the reboot.  SYNC records are written
 * often enough to minimize how much data is lost.  Generally, these records
 * will be written after some amount of time and after so many records or
 * sectors have been written.  Which ever comes first.
 *
 * SYNC_MAJIK is layed down in both REBOOT and SYNC records.  It is the
 * majik looked for when we are resyncing.  It must always be at the same
 * offset from the start of the record.  Once SYNC_MAJIK is found we can
 * backup by that amount to find the start of the record and presto, back
 * in sync.
 */

#define SYNC_MAJIK 0xdedf00efUL

/*
 * reboot record
 * followed by ow_control_block
 *
 * We need to pad out the reboot record to keep 2quad alignment for the
 * following ow_control_block.
 */

typedef struct {
  uint16_t len;                 /* size 36 +    116     */
  dtype_t  dtype;               /* reboot  + ow_control */
  uint32_t recnum;
  rtctime_t rt;                 /* 10 byte rtctime, 2quad align */
  uint16_t recsum;              /* part of header */
  uint32_t prev_sync;           /* file offset */
  uint32_t sync_majik;
  /* above same as sync */

  /* additional in reboot record + owcb */
  uint16_t core_rev;            /* core_rev level                      */
                                /* and associated structures           */
  uint16_t core_minor;          /* things changed but not structurally */
  uint32_t base;                /* base address of running image       */
} PACKED dt_reboot_t;

typedef struct {
  dt_reboot_t dt_reboot;
  ow_control_block_t dt_owcb;
} PACKED dt_dump_reboot_t;


/*
 * version record
 *
 * simple version information
 * followed by the entire image_info block
 */
typedef struct {
  uint16_t    len;              /* size   24    +   24 + 292   */
  dtype_t     dtype;            /* dt_version_t + image_info_t */
  uint32_t    recnum;
  rtctime_t   rt;               /* 10 byte rtctime             */
  uint16_t    recsum;           /* part of header */
  uint32_t    base;             /* base address of this image  */
} PACKED dt_version_t;          /* quad granular */

typedef struct {
  dt_version_t dt_ver;
  image_info_t dt_image_info;
} dt_dump_version_t;


typedef struct {
  uint16_t   len;               /* size 28 */
  dtype_t    dtype;
  uint32_t   recnum;
  rtctime_t  rt;                /* 10 byte rtctime, 2quad align */
  uint16_t   recsum;            /* part of header */
  uint32_t   prev_sync;         /* file offset */
  uint32_t   sync_majik;
} PACKED dt_sync_t;             /* quad granular */


typedef enum {
  DT_EVENT_NONE             = 0,

  DT_EVENT_PANIC_WARN       = 1,
  DT_EVENT_FAULT            = 2,

  DT_EVENT_GPS_GEO          = 3,
  DT_EVENT_GPS_XYZ          = 4,
  DT_EVENT_GPS_TIME         = 5,
  DT_EVENT_GPS_MTFF_TIME    = 6,       // Mpm To First Fix (MTFF)
  DT_EVENT_GPS_FIRST_LOCK   = 7,       // boot to first lock

  DT_EVENT_SSW_DELAY_TIME   = 8,
  DT_EVENT_SSW_BLK_TIME     = 9,
  DT_EVENT_SSW_GRP_TIME     = 10,

  DT_EVENT_SURFACED         = 11,
  DT_EVENT_SUBMERGED        = 12,
  DT_EVENT_DOCKED           = 13,
  DT_EVENT_UNDOCKED         = 14,

  DT_EVENT_DCO_REPORT       = 15,
  DT_EVENT_DCO_SYNC         = 16,

  /***********************************/

  DT_EVENT_GPS_BOOT         = 32,
  DT_EVENT_GPS_BOOT_TIME    = 33,
  DT_EVENT_GPS_BOOT_FAIL    = 34,

  DT_EVENT_GPS_MON_MINOR    = 35,
  DT_EVENT_GPS_MON_MAJOR    = 36,

  DT_EVENT_GPS_RX_ERR       = 37,
  DT_EVENT_GPS_LOST_INT     = 38,
  DT_EVENT_GPS_MSG_OFF      = 39,

  DT_EVENT_GPS_AWAKE_S      = 40,
  DT_EVENT_GPS_CMD          = 41,
  DT_EVENT_GPS_RAW_TX       = 42,
  DT_EVENT_GPS_SWVER_TO     = 43,
  DT_EVENT_GPS_CANNED       = 44,

  DT_EVENT_GPS_HW_CONFIG    = 45,
  DT_EVENT_GPS_RECONFIG     = 46,

  DT_EVENT_GPS_TURN_ON      = 47,
  DT_EVENT_GPS_STANDBY      = 48,
  DT_EVENT_GPS_TURN_OFF     = 49,
  DT_EVENT_GPS_MPM          = 50,
  DT_EVENT_GPS_PULSE        = 51,

  DT_EVENT_GPS_TX_RESTART   = 52,
  DT_EVENT_GPS_MPM_RSP      = 53,

  /***********************************/

  DT_EVENT_GPS_FAST         = 64,
  DT_EVENT_GPS_FIRST        = 65,
  DT_EVENT_GPS_SATS_2       = 66,
  DT_EVENT_GPS_SATS_7       = 67,
  DT_EVENT_GPS_SATS_41      = 68,

  DT_EVENT_16               = 0xffff,
} dt_event_id_t;


typedef struct {
  uint16_t len;                 /* size 40 */
  dtype_t  dtype;
  uint32_t recnum;
  rtctime_t rt;                 /* 10 byte rtctime, 2quad align */
  uint16_t recsum;              /* part of header */
  dt_event_id_t ev;             /* 2 bytes, event, see above */
  uint8_t  pcode;               /* PANIC warn, pcode, subsys */
  uint8_t  w;                   /* PANIC warn, where  */
  uint32_t arg0;
  uint32_t arg1;
  uint32_t arg2;
  uint32_t arg3;
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
 */
typedef struct {
  uint16_t len;                 /* size 28 + var */
  dtype_t  dtype;
  uint32_t recnum;
  rtctime_t rt;                 /* 10 byte rtctime, 2quad align */
  uint16_t recsum;              /* part of header */
  uint32_t mark_us;             /* mark stamp in usecs */
  gps_chip_id_t chip_id;        /* 1 byte */
  uint8_t  dir;                 /* dir, 0 rx from gps, 1 - tx to gps */
  uint16_t pad;                 /* quad alignment */
} PACKED dt_gps_t;

/* direction setting in dir in dt_gps_t
 *
 * DIR_RX: packet received from the GPS chip
 * DIR_TX: packet sent to the GPS chip
 */
#define GPS_DIR_RX 0
#define GPS_DIR_TX 1


typedef struct {
  uint16_t len;                 /* size 28 + var */
  dtype_t  dtype;
  uint32_t recnum;
  rtctime_t rt;                 /* 10 byte rtctime, 2quad align */
  uint16_t recsum;              /* part of header */
  uint32_t sched_delta;
  uint16_t sns_id;
  uint16_t pad;                 /* quad alignment */
} PACKED dt_sensor_data_t;


typedef struct {
  uint16_t len;                 /* size 28 + var */
  dtype_t  dtype;
  uint32_t recnum;
  rtctime_t rt;                 /* 10 byte rtctime, 2quad align */
  uint16_t recsum;              /* part of header */
  uint32_t sched_delta;
  uint16_t mask;
  uint16_t mask_id;
} PACKED dt_sensor_set_t;


/*
 * Note
 *
 * arbritrary ascii string sent from the base station.
 * one use is when calibrating the device.  Can also be used to add notes
 * about conditions the tag is being placed in.
 *
 * Typically the note will be a NULL terminated ascii string but it is completely
 * up to the base station as to what it sends.  Typically the NULL will be included
 * in the length.
 *
 * There is nothing special about the note structure so it is simply a dt_header_t
 * labelled as dt_note_t.
 */

typedef dt_header_t dt_note_t;          /* size 20 + var note size */


/*
 * GPS Proto Stats
 * report instrumentation from the GPS protocol stack.
 *
 * The data is essentially a copy of the first part of the data in
 * sirfbin_stat_t (sirf_driver.h).
 *
 * The header is a dt_header_t followed dt_gps_proto_stats_t.  dt_header_t is
 * guaranteed to be word aligned/word granular.
 *
 * dt_gps_proto_stats_t is used both internally as well as in the dblk stream.
 * Do not PACK it.  Leave native.  It will work in both cases.
 */

typedef struct {
  uint32_t starts;                    /* number of packets started */
  uint32_t complete;                  /* number completed successfully */
  uint32_t ignored;                   /* number of bytes ignored */
  uint16_t resets;                    /* protocol resets (aborts) */
  uint16_t too_small;                 /* too large, aborted */
  uint16_t too_big;                   /* too large, aborted */
  uint16_t chksum_fail;               /* bad checksum */
  uint16_t rx_timeouts;               /* number of rx timeouts */
  uint16_t rx_errors;                 /* rx_error, comm h/w not happy */
  uint16_t rx_framing;                /* framing errors */
  uint16_t rx_overrun;                /* overrun errors */
  uint16_t rx_parity;                 /* parity errors  */
  uint16_t proto_start_fail;          /* proto fails at start of packet */
  uint16_t proto_end_fail;            /* proto fails at end   of packet */
} dt_gps_proto_stats_t;


/*
 * TAGNET
 *
 * A Tagnet Dtype simply encapsulate a complete Tagnet packet and stashes it
 * in the data stream.
 *
 * To interpret it, one needs a tagnet parser.
 */

typedef dt_header_t dt_tagnet_t;          /* size 20 + var tagnet size */

enum {
  DT_HDR_SIZE_HEADER        = sizeof(dt_header_t),
  DT_HDR_SIZE_REBOOT        = sizeof(dt_reboot_t),
  DT_HDR_SIZE_VERSION       = sizeof(dt_version_t),
  DT_HDR_SIZE_SYNC          = sizeof(dt_sync_t),
  DT_HDR_SIZE_EVENT         = sizeof(dt_event_t),

  DT_HDR_SIZE_GPS           = sizeof(dt_gps_t),
  DT_HDR_SIZE_SENSOR_DATA   = sizeof(dt_sensor_data_t),
  DT_HDR_SIZE_SENSOR_SET    = sizeof(dt_sensor_set_t),
  DT_HDR_SIZE_NOTE          = sizeof(dt_note_t),
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
