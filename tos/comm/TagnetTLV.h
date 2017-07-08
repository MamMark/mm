#ifndef __TAGNETTLV__
#define __TAGNETTLV__
/**
 * @author Daniel J. Maltbie (dmaltbie@daloma.org)
 *
 * @Copyright (c) 2017 Daniel J. Maltbie
 * All rights reserved.
 */
/*
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
 */

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

  TN_LAST_ID
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
  {TN_INFO_SENS_GPS_XYZ_ID,"\001\003pos","\001\017sens_gps_xyz help",UQ_TN_INFO_SENS_GPS_XYZ},
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


typedef struct {
  uint32_t gps_x;
  uint32_t gps_y;
  uint32_t gps_z;
} tagnet_gps_xyz_t;

#define TN_GPS_XYZ_LEN (sizeof(tagnet_gps_xyz_t))


#endif
