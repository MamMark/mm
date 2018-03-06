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

/**
 * This module provides functions for handling the Payload field
 * in a Tagnet Message
 *<p>
 * Every message has a name, but only some have a payload. The
 * payload is typically used to add parameters in a request
 * message or return read results in the response.
 *
 *</p>
 *<p>
 * There are functions to access the payload either as a raw
 * byte block or as a list of TLVs. Raw bytes are used when
 * transferring bulk data, like a binary image.
 * With TLVs, state information is maintained in Metadata to
 * perform getting the current and next TLV in the list. Finally,
 * there are functions to convert C Types to TLVs and store in the
 * payload. See TagnetPayload.nc for more details on these
 * functions.
 *</p>
 *<p>
 * Some functions provide payload length information, including
 * length of the current payload as well as length of remaining
 * available space in the message. Payload length is determined
 * by current metadata state while the message buffer size is
 * used to calculate remaining free space
 *</p>
 *<p>
 * The message header fields are modified in certain cases, such
 * as the payload type field is set when data is written into
 * the message buffer. The message length is updated when the
 * data is added to the payload or the payload state is reset.
 *</p>
 *<p>
 * See TagnetPayload.nc for details of these functions.
 *</p>
 */

#include "message.h"
#include "Tagnet.h"
#include "TagnetTLV.h"

#define TN_PLOAD_DBG
//#define TN_PLOAD_DBG __attribute__((optimize("O0")))

module TagnetPayloadP {
  provides interface TagnetPayload;
  uses     interface TagnetHeader   as  THdr;
  uses     interface TagnetTLV      as  TTLV;
}
implementation {

  tagnet_payload_meta_t *getMeta(message_t *msg) {
    return (tagnet_payload_meta_t *) &(((message_metadata_t *)&(msg->metadata))->tn_payload_meta);
  }

  command uint8_t TN_PLOAD_DBG  TagnetPayload.add_block(message_t *msg, void *d, uint8_t length) {
    tagnet_tlv_t     *tv;
    int               added;

    tv = call TagnetPayload.this_element(msg);
    added = call TTLV.block_to_tlv(d, length, tv, call TagnetPayload.bytes_avail(msg));
    call THdr.set_pload_type_tlv(msg);
    call THdr.set_message_len(msg, call THdr.get_message_len(msg) + added);
    getMeta(msg)->this += added;
    return added;
  }

  command uint8_t TN_PLOAD_DBG  TagnetPayload.add_delay(message_t *msg, uint32_t n) {
    tagnet_tlv_t     *tv;
    int32_t           added;

    tv = call TagnetPayload.this_element(msg);
    added = call TTLV.delay_to_tlv(n, tv, call TagnetPayload.bytes_avail(msg));
    call THdr.set_pload_type_tlv(msg);
    call THdr.set_message_len(msg, call THdr.get_message_len(msg) + added);
    getMeta(msg)->this += added;
    return added;
  }

  command uint8_t TN_PLOAD_DBG  TagnetPayload.add_eof(message_t *msg) {
    tagnet_tlv_t     *tv;
    int32_t           added = 2;

    tv = call TagnetPayload.this_element(msg);
    tv->typ = TN_TLV_EOF;
    tv->len = 0;
    call THdr.set_pload_type_tlv(msg);
    call THdr.set_message_len(msg, call THdr.get_message_len(msg) + added);
    getMeta(msg)->this += added;
    return added;
  }

  command uint8_t TN_PLOAD_DBG  TagnetPayload.add_error(message_t *msg, int32_t err) {
    tagnet_tlv_t     *tv;
    int32_t           added;

    tv = call TagnetPayload.this_element(msg);
    added = call TTLV.error_to_tlv(err, tv, call TagnetPayload.bytes_avail(msg));
    call THdr.set_pload_type_tlv(msg);
    call THdr.set_message_len(msg, call THdr.get_message_len(msg) + added);
    getMeta(msg)->this += added;
    return added;
  }

  command uint8_t TN_PLOAD_DBG  TagnetPayload.add_gps_xyz(message_t *msg, tagnet_gps_xyz_t *xyz) {
    tagnet_tlv_t     *tv;
    int               added;

    tv = call TagnetPayload.this_element(msg);
    added = call TTLV.gps_xyz_to_tlv(xyz, tv, call TagnetPayload.bytes_avail(msg));
    call THdr.set_pload_type_tlv(msg);
    call THdr.set_message_len(msg, call THdr.get_message_len(msg) + added);
    getMeta(msg)->this += added;
    return added;
  }

  command uint8_t TN_PLOAD_DBG  TagnetPayload.add_integer(message_t *msg, int32_t n) {
    tagnet_tlv_t     *tv;
    int32_t           added;

    tv = call TagnetPayload.this_element(msg);
    added = call TTLV.integer_to_tlv(n, tv, call TagnetPayload.bytes_avail(msg));
    call THdr.set_pload_type_tlv(msg);
    call THdr.set_message_len(msg, call THdr.get_message_len(msg) + added);
    getMeta(msg)->this += added;
    return added;
  }

  command uint8_t TN_PLOAD_DBG  TagnetPayload.add_offset(message_t *msg, int32_t n) {
    tagnet_tlv_t     *tv;
    int32_t           added;

    tv = call TagnetPayload.this_element(msg);
    added = call TTLV.offset_to_tlv(n, tv, call TagnetPayload.bytes_avail(msg));
    call THdr.set_pload_type_tlv(msg);
    call THdr.set_message_len(msg, call THdr.get_message_len(msg) + added);
    getMeta(msg)->this += added;
    return added;
  }

  command uint8_t   TagnetPayload.add_raw(message_t *msg, uint8_t *b, uint8_t length) {
    uint8_t          *buf;
    int               added;

    if (length > call TagnetPayload.bytes_avail(msg))
      return 0;
    if (b) {
      buf = (uint8_t *) call TagnetPayload.first_element(msg);
      for (added = 0; added < length; added++) {
        buf[added] = b[added];
      }
    }
    call THdr.set_pload_type_raw(msg);
    call THdr.set_message_len(msg, call THdr.get_message_len(msg) + added);
    getMeta(msg)->this += added;
    return added;
  }

  command uint8_t TN_PLOAD_DBG  TagnetPayload.add_size(message_t *msg, int32_t sz) {
    tagnet_tlv_t     *tv;
    int32_t           added;

    tv = call TagnetPayload.this_element(msg);
    added = call TTLV.size_to_tlv(sz, tv, call TagnetPayload.bytes_avail(msg));
    call THdr.set_pload_type_tlv(msg);
    call THdr.set_message_len(msg, call THdr.get_message_len(msg) + added);
    getMeta(msg)->this += added;
    return added;
  }

  command uint8_t TN_PLOAD_DBG  TagnetPayload.add_string(message_t *msg, void *d, uint8_t length) {
    tagnet_tlv_t     *tv;
    int               added;

    tv = call TagnetPayload.this_element(msg);
    added = call TTLV.string_to_tlv(d, length, tv, call TagnetPayload.bytes_avail(msg));
    call THdr.set_pload_type_tlv(msg);
    call THdr.set_message_len(msg, call THdr.get_message_len(msg) + added);
    getMeta(msg)->this += added;
    return added;
  }

  command uint8_t TN_PLOAD_DBG  TagnetPayload.add_tlv(message_t *msg, tagnet_tlv_t *t) {
    tagnet_tlv_t     *tv;
    int               added;

    tv = call TagnetPayload.this_element(msg);
    added = call TTLV.copy_tlv(t, tv, call TagnetPayload.bytes_avail(msg));
    call THdr.set_pload_type_tlv(msg);
    call THdr.set_message_len(msg, call THdr.get_message_len(msg) + added);
    getMeta(msg)->this += added;
    return added;
  }

  command uint8_t TN_PLOAD_DBG  TagnetPayload.add_version(message_t *msg, image_ver_t *v) {
    tagnet_tlv_t     *tv = call TagnetPayload.this_element(msg);
    int               added;

    added = call TTLV.version_to_tlv(v, tv, call TagnetPayload.bytes_avail(msg));
    if (added) {
      call THdr.set_pload_type_tlv(msg);
      call THdr.set_message_len(msg, call THdr.get_message_len(msg) + added);
      getMeta(msg)->this += added;
    }
    return added;
  }

  command uint8_t  TN_PLOAD_DBG  TagnetPayload.bytes_avail(message_t* msg) {
    return (sizeof(msg->data) - call THdr.get_name_len(msg) - getMeta(msg)->this);
  }

  command tagnet_tlv_t* TN_PLOAD_DBG  TagnetPayload.first_element(message_t *msg) {
    memset(getMeta(msg),0,sizeof(tagnet_payload_meta_t));
    if (call TagnetPayload.get_len(msg))
      return (tagnet_tlv_t *) (&msg->data[call THdr.get_name_len(msg)]);
    else
      return NULL;
  }

  command uint8_t TN_PLOAD_DBG  TagnetPayload.get_len(message_t* msg) {
    // total packet length - size of header - size of Name = size of payload
    return (call THdr.get_message_len(msg)
              - call THdr.get_header_len(msg)
              - call THdr.get_name_len(msg));
  }

  command tagnet_tlv_t* TN_PLOAD_DBG TagnetPayload.next_element(message_t *msg) {
    tagnet_tlv_t *this_tlv;
    tagnet_tlv_t *next_tlv;
    uint8_t      *pload_start = (uint8_t *) &msg->data[call THdr.get_name_len(msg)];
    uint8_t      *p;

    if (call THdr.is_pload_type_raw(msg))
      return NULL;
    this_tlv = call TagnetPayload.this_element(msg);
    next_tlv = call TTLV.get_next_tlv(this_tlv, call TagnetPayload.bytes_avail(msg));
    if (next_tlv == NULL)
        return NULL;
    p = (uint8_t *)next_tlv;
    if ((p  > (uint8_t *)&msg->data[call THdr.max_user_bytes(msg)])
        || (p <= (uint8_t *)&pload_start[getMeta(msg)->this])) {
//      panic_warn();
      return NULL;
    }
    getMeta(msg)->this += call TTLV.get_len(this_tlv);    // advance 'this' to 'next' tlv in list
//    getMeta(msg)->this = (uint8_t *) next_tlv - pload_start;    // advance 'this' to 'next' tlv in list
    return next_tlv;
  }

  command void TN_PLOAD_DBG  TagnetPayload.reset_payload(message_t *msg) {
    getMeta(msg)->this = 0;
    call THdr.set_message_len(msg,
        call THdr.get_header_len(msg) + call THdr.get_name_len(msg));
  }

  command tagnet_tlv_t* TN_PLOAD_DBG TagnetPayload.this_element(message_t *msg) {
    return (tagnet_tlv_t *) (&(msg->data[getMeta(msg)->this + call THdr.get_name_len(msg)]));
  }
}
