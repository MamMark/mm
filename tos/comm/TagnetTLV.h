/**
 * @Copyright (c) 2017-2018 Daniel J. Maltbie
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
 * @author Daniel J. Maltbie (dmaltbie@daloma.org)
 */

#ifndef __TAGNETTLV_H__
#define __TAGNETTLV_H__

#include <Tagnet.h>
#include <TagnetAdapter.h>

// Tagnet TLV Types
typedef enum {
  TN_TLV_NONE       = 0,
  TN_TLV_STRING     = 1,
  TN_TLV_INTEGER    = 2,
  TN_TLV_GPS_XYZ    = 3,
  TN_TLV_UTC_TIME   = 4,
  TN_TLV_NODE_ID    = 5,
  TN_TLV_NODE_NAME  = 6,
  TN_TLV_OFFSET     = 7,
  TN_TLV_SIZE       = 8,
  TN_TLV_EOF        = 9,
  TN_TLV_VERSION    = 10,
  TN_TLV_BLK        = 11,
  TN_TLV_RECNUM     = 12,
  TN_TLV_RECCNT     = 13,
  TN_TLV_DELAY      = 14,
  TN_TLV_ERROR      = 15,
  TN_TLV_APP1       = 20,
  TN_TLV_APP2       = 21,
  _TN_TLV_COUNT   // limit of enum values
} tagnet_tlv_type_t;

// tagnet tlv type, len, value structure
typedef struct tagnet_tlv_t {
  tagnet_tlv_type_t typ;
  uint8_t           len;
  uint8_t           val[];
} tagnet_tlv_t;

// 'standard' TLVs
#define TN_NONE_TLV          "\000\000"
#define TN_BCAST_NID_TLV     "\005\006\xff\xff\xff\xff\xff\xff"
#define TN_MY_NID_TLV        "\005\006\x42\x42\x42\x42\x42\x42"
#define TN_TAG_TLV           "\001\003tag"

#define SIZEOF_TLV(t) (t->len + sizeof(tagnet_tlv_t))

#endif   /* __TAGNETTLV_H__ */
