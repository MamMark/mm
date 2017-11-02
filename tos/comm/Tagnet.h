/*
 * @Copyright (c) 2017 Daniel J. Maltbie
 * All rights reserved.
 *
 * Redistribution and use in source and binary forms, with or without
 * modification, are permitted provided that the following conditions
 * are met:
 *
 * - Redistributions of source code must retain the above copyright
 *   notice, this list of conditions and the following disclaimer.
 *
 * - Redistributions in binary form must reproduce the above copyright
 *   notice, this list of conditions and the following disclaimer in the
 *   documentation and/or other materials provided with the
 *   distribution.
 *
 * - Neither the name of the copyright holders nor the names of
 *   its contributors may be used to endorse or promote products derived
 *   from this software without specific prior written permission.
 *
 * THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS
 * "AS IS" AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT
 * LIMITED TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS
 * FOR A PARTICULAR PURPOSE ARE DISCLAIMED.  IN NO EVENT SHALL
 * THE COPYRIGHT HOLDER OR CONTRIBUTORS BE LIABLE FOR ANY DIRECT,
 * INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES
 * (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR
 * SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION)
 * HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT,
 * STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE)
 * ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED
 * OF THE POSSIBILITY OF SUCH DAMAGE.
 *
 * @author Daniel J. Maltbie <dmaltbie@daloma.org>
 */

#ifndef __TAGNET_H__
#define __TAGNET_H__

#include <TagnetTLV.h>

typedef enum {
  TN_POLL                = 0,
  TN_BEACON              = 1,
  TN_HEAD                = 2,
  TN_PUT                 = 3,
  TN_GET                 = 4,
  TN_DELETE              = 5,
  TN_OPTION              = 6,
  TN_RESERVED            = 7, // maximum of seven types
  _TN_COUNT              // limit of enum
} tagnet_msg_type_t;

typedef enum {
  TE_PKT_OK              = 0,
  TE_NO_ROUTE,
  TE_TOO_MANY_HOPS,
  TE_MTU_EXCEEDED,
  TE_UNSUPPORTED,
  TE_BAD_MESSAGE,
  TE_FAILED,
  TE_PKT_NO_MATCH,
  TE_BUSY,
} tagnet_error_t;

typedef struct tagnet_name_meta_t {
  uint8_t     this;
  uint8_t     offset;
  uint8_t     version;
  uint8_t     size;
  uint8_t     utc_time;
  uint8_t     node_id;
  uint8_t     gps_xyz;
} tagnet_name_meta_t;

typedef struct tagnet_payload_meta_t {
  uint8_t     this;
} tagnet_payload_meta_t;

// unique ids used for wiring to generic modules
#define UQ_TN_ROOT              "UQ_TN_ROOT"
#define UQ_TN_TAG               "UQ_TN_TAG"
#define UQ_TN_POLL              "UQ_TN_POLL"
#define UQ_TN_POLL_NID          "UQ_TN_POLL_NID"
#define UQ_TN_POLL_EV           "UQ_TN_POLL_EV"
#define UQ_TN_POLL_CNT          "UQ_TN_POLL_CNT"
#define UQ_TN_SENS              "UQ_TN_SENS"
#define UQ_TN_SENS_GPS          "UQ_TN_SENS_GPS"
#define UQ_TN_SENS_GPS_XYZ      "UQ_TN_SENS_GPS_XYZ"
#define UQ_TN_INFO              "UQ_TN_INFO"
#define UQ_TN_INFO_NID          "UQ_TN_INFO_NID"
#define UQ_TN_INFO_SENS         "UQ_TN_INFO_SENS"
#define UQ_TN_INFO_SENS_GPS     "UQ_TN_INFO_SENS_GPS"
#define UQ_TN_INFO_SENS_GPS_XYZ "UQ_TN_INFO_SENS_GPS_XYZ"
#define UQ_TN_SD                "UQ_TN_SD"
#define UQ_TN_SD_NID            "UQ_TN_SD_NID"
#define UQ_TN_SD_DEV_0          "UQ_TN_SD_DEV_0"
#define UQ_TN_SD_DEV_0_IMG      "UQ_TN_SD_DEV_0_IMG"
#define UQ_TN_SYS               "UQ_TN_SYS"
#define UQ_TN_SYS_NID           "UQ_TN_SYS_NID"
#define UQ_TN_SYS_ACTIVE        "UQ_TN_SYS_ACTIVE"
#define UQ_TN_SYS_BACKUP        "UQ_TN_SYS_BACKUP"
#define UQ_TN_SYS_GOLDEN        "UQ_TN_SYS_GOLDEN"
#define UQ_TN_SYS_NIB           "UQ_TN_SYS_NIB"
#define UQ_TN_SYS_RUNNING       "UQ_TN_SYS_RUNNING"

#define UQ_TAGNET_ADAPTER_LIST  "UQ_TAGNET_ADAPTER_LIST"

// index into tn_named_data_descriptors
typedef enum {
  TN_ROOT_ID,
  TN_TAG_ID,

  TN_POLL_ID,
  TN_POLL_NID_ID,
  TN_POLL_EV_ID,
  TN_POLL_CNT_ID,

  TN_INFO_ID,
  TN_INFO_NID_ID,
  TN_INFO_SENS_ID,
  TN_INFO_SENS_GPS_ID,
  TN_INFO_SENS_GPS_XYZ_ID,

  TN_SD_ID,
  TN_SD_NID_ID,
  TN_SD_DEV_0_ID,
  TN_SD_DEV_0_IMG_ID,

  TN_SYS_ID,
  TN_SYS_NID_ID,
  TN_SYS_ACTIVE_ID,
  TN_SYS_BACKUP_ID,
  TN_SYS_GOLDEN_ID,
  TN_SYS_NIB_ID,
  TN_SYS_RUNNING_ID,

  TN_LAST_ID,
  TN_MAX_ID = 65000,  // force two byte enum size
} tn_ids_t;

/* structure used to hold configuration values for each of the elements
 * in the tagnet named data tree
 */
typedef struct TN_data_t {
  tn_ids_t    id;
  char*       name_tlv;
  char*       help_tlv;
  char*       uq;
} TN_data_t;

/*
 * Indexed using tn_ids_t from above.
 *
 * Ids must be kept in sync with the row index in this table.
 */

const TN_data_t tn_name_data_descriptors[TN_LAST_ID]={
  {TN_ROOT_ID,"\000\000","\001\009root help",UQ_TN_ROOT},
  {TN_TAG_ID,TN_TAG_TLV,"\001\008tag help",UQ_TN_TAG},

  {TN_POLL_ID,"\001\004poll","\001\009poll help",UQ_TN_POLL},
  {TN_POLL_NID_ID,TN_BCAST_NID_TLV,"\1\13poll_nid help",UQ_TN_POLL_NID},
  {TN_POLL_EV_ID,"\001\002ev","\001\012poll_ev help",UQ_TN_POLL_EV},
  {TN_POLL_CNT_ID,"\001\003cnt","\001\013poll_cnt help",UQ_TN_POLL_CNT},

  {TN_INFO_ID,"\001\004info","\001\009info help",UQ_TN_INFO},
  {TN_INFO_NID_ID,TN_BCAST_NID_TLV,"\1\13info_nid help",UQ_TN_INFO_NID},
  {TN_INFO_SENS_ID,"\001\004sens","\001\011sensor help",UQ_TN_INFO_SENS},
  {TN_INFO_SENS_GPS_ID,"\001\003gps","\001\013sens_gps help",UQ_TN_INFO_SENS_GPS},
  {TN_INFO_SENS_GPS_XYZ_ID,"\001\003xyz","\001\017sens_gps_xyz help",UQ_TN_INFO_SENS_GPS_XYZ},

  {TN_SD_ID,"\001\002sd","\001\007sd help",UQ_TN_SD},
  {TN_SD_NID_ID,TN_BCAST_NID_TLV,"\1\11sd_nid help",UQ_TN_SD_NID},
  {TN_SD_DEV_0_ID,"\002\001\000","\001\009sd_0 help",UQ_TN_SD_DEV_0},
  {TN_SD_DEV_0_IMG_ID,"\001\003img","\001\014sd_0_img help",UQ_TN_SD_DEV_0_IMG},

  {TN_SYS_ID,         "\x01\x03sys",    "\x01\x08sys help",        UQ_TN_SYS},
  {TN_SYS_NID_ID,     TN_BCAST_NID_TLV, "\x01\x0Csys_nid help",    UQ_TN_SYS_NID},
  {TN_SYS_ACTIVE_ID,  "\x01\006active", "\x01\x0Fsys_active help", UQ_TN_SYS_ACTIVE},
  {TN_SYS_BACKUP_ID,  "\x01\006backup", "\x01\x0Fsys_backup help", UQ_TN_SYS_BACKUP},
  {TN_SYS_GOLDEN_ID,  "\x01\x06golden", "\x01\x0Fsys_golden help", UQ_TN_SYS_GOLDEN},
  {TN_SYS_NIB_ID,     "\x01\x03nib",    "\x01\x0Csys_nib help",    UQ_TN_SYS_NIB},
  {TN_SYS_RUNNING_ID, "\x01\x07running","\x01\x10sys_running help",UQ_TN_SYS_RUNNING},
};

/*
 * Tagnet name parsing trace array
 */
#define TN_TRACE_PARSE_ARRAY_SIZE  64

typedef struct tagnet_trace_parse {
  tn_ids_t     id;
  uint8_t      loc;
} tagnet_trace_parse_t;

tagnet_trace_parse_t  tn_trace_array[TN_TRACE_PARSE_ARRAY_SIZE];
uint32_t              tn_trace_index;

void tn_trace_rec(tn_ids_t id, uint8_t loc) {
  tn_trace_array[tn_trace_index].id = id;
  tn_trace_array[tn_trace_index].loc = loc;
  if (tn_trace_index < TN_TRACE_PARSE_ARRAY_SIZE) tn_trace_index++;
}

#ifdef notdef
!!! include this in the HEAD response to designate the format of payload
from https://pythonhosted.org/txdbus/dbus_overview.html
Character	Code Data Type
y  8-bit unsigned integer
b  boolean value
n  16-bit signed integer
q  16-bit unsigned integer
i  32-bit signed integer
u  32-bit unsigned integer
x  64-bit signed integer
t  64-bit unsigned integer
d  double-precision floating point (IEEE 754)
s  UTF-8 string (no embedded nul characters)
o  D-Bus Object Path string
g  D-Bus Signature string
a  Array
(  Structure start
)  Structure end
v  Variant type (described below)
{  Dictionary/Map begin
}  Dictionary/Map end
h  Unix file descriptor

additional info @ https://dbus.freedesktop.org/doc/dbus-specification.html#type-system
#endif

#endif          /* __TAGNET_H__ */
