/**
 * @Copyright (c) 2017-2018 Daniel J. Maltbie
 * All rights reserved.

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
 * This module provides functions for adapting system execution
 * control variables.
 */

#include <message.h>
#include <Tagnet.h>
#include <TagnetTLV.h>
#include <image_info.h>
#include <overwatch.h>
#include "wds_configs.h"

typedef struct poll_req_s {
  uint8_t  *node_id;
  uint8_t  *node_name;
  uint32_t slot_width;
  uint32_t slot_count;
  uint8_t  nid_len;
  uint8_t  name_len;
  bool     has_slot_width;
  bool     has_slot_count;
} poll_req_t;

module TagnetPollExecP {
  provides interface TagnetAdapter<int32_t>    as PollCount;
  provides interface TagnetAdapter<message_t>  as PollEvent;
  uses     interface TagnetName                as  TName;
  uses     interface TagnetHeader              as  THdr;
  uses     interface TagnetPayload             as  TPload;
  uses     interface TagnetTLV                 as  TTLV;
  uses     interface ImageManagerData          as  IMD;
  uses     interface OverWatch                 as  OW;
  uses     interface Collect;
  uses     interface Random;
  uses     interface PacketField<uint16_t>     as  PacketTransmitDelay;
}
implementation {
  int32_t poll_count = 0;

  /*
   * given an incoming msg, extract various msg parameters from
   * payload: time, slot_width, slot_count, node_id, node_name.
   */
  void get_params(poll_req_t *params, message_t *msg) {
    tagnet_tlv_t    *a_tlv;
    uint8_t          i;

    a_tlv = call TPload.first_element(msg);
    for (i = 0; i < 4; i++) {
      if (a_tlv == NULL) break;

      switch (call TTLV.get_tlv_type(a_tlv)) {
        case TN_TLV_INTEGER:
          if (!params->has_slot_width) {
            // slot width is specified in number of bits
            params->slot_width = call TTLV.tlv_to_integer(a_tlv);
            params->has_slot_width = TRUE;
          } else {
            // total number of slots of width bits
            params->slot_count = call TTLV.tlv_to_integer(a_tlv);
            params->has_slot_count = TRUE;
          }
          break;
        case TN_TLV_NODE_ID:
          params->nid_len = call TTLV.get_len_v(a_tlv);
          params->node_id = call TTLV.tlv_to_node_id(a_tlv);
          break;
        case TN_TLV_NODE_NAME:
          params->name_len = call TTLV.get_len_v(a_tlv);
          params->node_name = call TTLV.tlv_to_node_name(a_tlv);
          break;
        default:
          break;
      }
      a_tlv  = call TPload.next_element(msg);
    }
  }


  /*
   * slots nums go from 1 to 645 or so
   * delays go from 0 to at most 64534 mis
   */
  uint16_t  get_time_to_wait(poll_req_t *params) {
    wds_config_ids_t const* ids =   wds_default_ids();
    uint16_t            slotnum;
    uint32_t           slottime =   102; /* mis */
    uint32_t         us_per_bit;

    if (!params->has_slot_count || !params->has_slot_width)
      return -1;                        /* must see both to be valid */

    // pick random slot to occupy
    slotnum = call Random.rand16() % params->slot_count;

    // convert modem data rate to microseconds per bit, then
    //use to calculate total slot time from slot bit width
    us_per_bit = 1000000 / ids->symb_sec;
    slottime   = (params->slot_width * us_per_bit);
    slottime  /= 1000; // microsecs to millisecs
    slottime = (slottime * 1024)/1000;        /* mis */
    return (slotnum * slottime);
  }


  command bool PollCount.get_value(int32_t *t, uint32_t *l) {
    *t = poll_count;
    *l = sizeof(int32_t);
    return TRUE;
  }

  command bool PollCount.set_value(int32_t *t, uint32_t *l) {
    return FALSE;
  }


  command bool PollEvent.get_value(message_t *msg, uint32_t *l) {
    poll_req_t     poll_params = {0,0,0,0,0,0,0,0};
    dt_header_t    dt_hdr;
    uint16_t       delay;

    nop();                            /* BRK */
    switch (call THdr.get_message_type(msg)) {    // process packet type
      case TN_POLL:
        poll_count++;
        dt_hdr.len = call THdr.get_message_len(msg) + sizeof(dt_hdr);
        dt_hdr.dtype = DT_TAGNET;
        call Collect.collect(&dt_hdr, sizeof(dt_hdr),
                             (uint8_t *) msg,
                             call THdr.get_message_len(msg));
        get_params(&poll_params, msg);
        call TPload.reset_payload(msg);
        call THdr.set_response(msg);
        call TPload.add_tlv(msg, TN_MY_NID_TLV);
        // zzz node name, position, sw version
        delay = get_time_to_wait(&poll_params);
        if (delay == -1)
          return FALSE;
        call TPload.add_integer(msg, delay);
        call PacketTransmitDelay.set(msg, delay);
        return TRUE;

      case TN_GET:
        // here return poll count and eOk
        call TPload.reset_payload(msg);
        call THdr.set_response(msg);
        call TPload.add_integer(msg, poll_count);
        return TRUE;

      case TN_HEAD:
        // return eOk, with offset of zero and size of pollcount
        call TPload.reset_payload(msg);     // clear payload
        call THdr.set_response(msg);
        call TPload.add_offset(msg, 0);     // default file size
        call TPload.add_size(msg, poll_count);
        return TRUE;

      default:
        break;
    }
    call THdr.set_error(msg, TE_PKT_NO_MATCH);
    return FALSE;                                  // no match, do nothing
  }

  command bool PollEvent.set_value(message_t *msg, uint32_t *l) {
    return FALSE;
  }


  event void Collect.resyncDone(error_t err, uint32_t offset) { }
  event void Collect.collectBooted() { }
}
