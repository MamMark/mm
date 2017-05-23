/**
 * Copyright (c) 2017 Daniel J. Maltbie
 * All rights reserved.
 *
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
 * @author Daniel J. Maltbie <dmaltbie@daloma.org>
 *
 */

#include "message.h"
#include "Tagnet.h"
#include "TagnetTLV.h"

#define TN_PLOAD_DBG __attribute__((optimize("O0")))

module TagnetPayloadP {
  provides interface TagnetPayload;
  uses     interface TagnetHeader   as  THdr;
  uses     interface TagnetTLV      as  TTLV;
}
implementation {

  tagnet_name_meta_t *getMeta(message_t *msg) {
    return (tagnet_name_meta_t *) &(((message_metadata_t *)&(msg->metadata))->tn_payload_meta);
  }

  command uint8_t TN_PLOAD_DBG  TagnetPayload.add_integer(message_t *msg, int n) {
    tagnet_tlv_t     *tv;
    int               added;

    tv = call TagnetPayload.this_element(msg);
    added = call TTLV.integer_to_tlv(n, tv, call TagnetPayload.bytes_avail(msg));
    call THdr.set_pload_type_tlv(msg);
    call THdr.set_message_len(msg, call THdr.get_message_len(msg) + added);
    getMeta(msg)->this += added;
    return added;
  }

  command uint8_t   TagnetPayload.add_raw(message_t *msg, uint8_t *b, uint8_t length) {
    tagnet_tlv_t     *this;
    uint8_t          *buf;
    int               added;

    this = call TagnetPayload.first_element(msg);
    if (length > call TagnetPayload.bytes_avail(msg))
      return 0;
    buf = (uint8_t *) this;
    for (added = 0; added < length; added++) {
      buf[added] = b[added];
    }
    call THdr.set_pload_type_raw(msg);
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

  command uint8_t  TN_PLOAD_DBG  TagnetPayload.bytes_avail(message_t* msg) {
    return (sizeof(msg->data) - call THdr.get_name_len(msg) - getMeta(msg)->this);
  }

  command tagnet_tlv_t* TN_PLOAD_DBG  TagnetPayload.first_element(message_t *msg) {
    memset(getMeta(msg),0,sizeof(tagnet_payload_meta_t));
    return (tagnet_tlv_t *) (&msg->data[call THdr.get_name_len(msg)]);
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
    call THdr.set_message_len(msg, call THdr.get_header_len(msg)
                                      + call THdr.get_name_len(msg));
  }

  command tagnet_tlv_t* TN_PLOAD_DBG TagnetPayload.this_element(message_t *msg) {
    return (tagnet_tlv_t *) (&(msg->data[getMeta(msg)->this + call THdr.get_name_len(msg)]));
  }
}
