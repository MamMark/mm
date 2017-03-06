/**
 * Copyright (c) 2016, 2017 Dan Maltbie
 * @author Dan Maltbie
 */

#ifndef __TAGNET_H__
#define __TAGNET_H__

#include "tagnetTLV.h"

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
  TE_PACKET_OK           = 0,
  TE_NO_ROUTE,
  TE_TOO_MANY_HOPS,
  TE_MTU_EXCEEDED,
  TE_UNSUPPORTED,
  TE_BAD_MESSAGE,
  TE_FAILED,
  TE_PKT_NO_MATCH
} tagnet_error_t;

typedef struct tagnet_name_meta_t {
  uint8_t     first;
  uint8_t     this;
  uint8_t     seq_no;
  uint8_t     utc_time;
  uint8_t     node_id;
  uint8_t     gps_pos;
} tagnet_name_meta_t;

typedef struct tagnet_payload_meta_t {
  uint8_t     first;
  uint8_t     this;
} tagnet_payload_meta_t;

// 'standard' TLVs
#define TN_NONE_TLV          "\000\000"
#define TN_BCAST_NID_TLV     "\005\006\255\255\255\255\255\255"
#define TN_MY_NID_TLV        "\005\006\042\042\042\042\042\042"
#define TN_TAG_TLV           "\001\003tag"



/* structure used to hold configuration values for each of the elements
 * in the tagnet named data tree
 */
typedef struct TN_data_t {
  int         id;
  char*       name_tlv;
  char*       help_tlv;
  char*       uq;
} TN_data_t;

#define UQ_TN_ROOT              "UQ_TN_ROOT"
#define UQ_TN_TAG               "UQ_TN_TAG"
#define UQ_TN_POLL              "UQ_TN_POLL"
#define UQ_TN_POLL_NID          "UQ_TN_POLL_NID"
#define UQ_TN_POLL_EV           "UQ_TN_POLL_EV"
#define UQ_TN_POLL_CNT          "UQ_TN_POLL_CNT"
#define UQ_TN_SENS              "UQ_TN_SENS"
#define UQ_TN_SENS_GPS          "UQ_TN_SENS_GPS"
#define UQ_TN_SENS_GPS_POS      "UQ_TN_SENS_GPS_POS"
#define UQ_TN_INFO              "UQ_TN_INFO"
#define UQ_TN_INFO_NID          "UQ_TN_INFO_NID"
#define UQ_TN_INFO_SENS         "UQ_TN_INFO_SENS"
#define UQ_TN_INFO_SENS_GPS     "UQ_TN_INFO_SENS_GPS"
#define UQ_TN_INFO_SENS_GPS_POS "UQ_TN_INFO_SENS_GPS_POS"

#define UQ_TAGNET_ADAPTER_LIST  "UQ_TAGNET_ADAPTER_LIST"

// index into tn_named_data_descriptors
enum {
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
  TN_INFO_SENS_GPS_POS_ID,

  TN_LAST_ID
};

/*
 * Index list above must be kept in sync with the row order
 * in this table
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
  {TN_INFO_SENS_GPS_POS_ID,"\001\003pos","\001\017sens_gps_pos help",UQ_TN_INFO_SENS_GPS_POS},
};

#endif          /* __TAGNET_H__ */
