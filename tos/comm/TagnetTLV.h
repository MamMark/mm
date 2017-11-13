/**
 * Copyright (c) 2017 Daniel J. Maltbie
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
 * @author Daniel J. Maltbie (dmaltbie@daloma.org)
 *
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
