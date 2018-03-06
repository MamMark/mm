/**
 * @Copyright (c) 2017 Daniel J. Maltbie
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
 * @author Daniel J. Maltbie <dmaltbie@daloma.org>
 */

#ifndef __TAGNET_H__
#define __TAGNET_H__

/*
 * INCLUDE THE AUTO-GENERATED FILE HERE
 *
 * MUST BE INCLUDED ONCE ONLY HERE
 */
#include <TagnetDefines.h>

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

typedef enum {
  TN_E_APP_OK            =  0,
  TN_E_APP_EOF           =  1,
  TN_E_APP_BIS           =  2,
} tagnet_app_err_t;

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
