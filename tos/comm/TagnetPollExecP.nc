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

module TagnetPollExecP {
  provides interface TagnetAdapter<int32_t>    as PollCount;
  provides interface TagnetAdapter<message_t>  as PollEvent;
  uses     interface TagnetName                as  TName;
  uses     interface TagnetHeader              as  THdr;
  uses     interface TagnetPayload             as  TPload;
  uses     interface TagnetTLV                 as  TTLV;
  uses     interface ImageManagerData          as  IMD;
  uses     interface OverWatch                 as  OW;
}
implementation {
  int32_t poll_count = 0;

  command bool PollCount.get_value(int32_t *t, uint32_t *l) {
    nop();
    nop();
    *t = poll_count;
    *l = sizeof(int32_t);
    return TRUE;
  }
  command bool PollCount.set_value(int32_t *t, uint32_t *l) {
    return FALSE;
  }

  command bool PollEvent.get_value(message_t *msg, uint32_t *l) {
    tagnet_tlv_t    *this_tlv;
    int32_t          d;
    nop();
    nop();
    poll_count++;
    switch (call THdr.get_message_type(msg)) {    // process packet type
      case TN_POLL:
        // payload contains: time, slot_time, slot_count, node_id, node_name
        this_tlv = call TPload.first_element(msg);
        if ((this_tlv) && (call TTLV.get_tlv_type(this_tlv) == TN_TLV_UTC_TIME)) {
          nop();
          this_tlv = call TPload.next_element(msg);
        }
        if ((this_tlv) && (call TTLV.get_tlv_type(this_tlv) == TN_TLV_INTEGER)) {
          nop();
          this_tlv = call TPload.next_element(msg);
        }
        if ((this_tlv) && (call TTLV.get_tlv_type(this_tlv) == TN_TLV_INTEGER)) {
          d = call TTLV.tlv_to_integer(this_tlv);
          if (d) {
            nop();
          }
          this_tlv = call TPload.next_element(msg);
        }
        // zzz get request parameters from payload
        call TPload.reset_payload(msg);
        // zzz add node id, node name, position, sw version
        call TPload.add_tlv(msg, TN_MY_NID_TLV);
        call THdr.set_response(msg);
        call THdr.set_error(msg, TE_PKT_OK);
        return TRUE;
      case TN_GET:
        call TPload.reset_payload(msg);
        call TPload.add_integer(msg, poll_count);
        call THdr.set_response(msg);
        call THdr.set_error(msg, TE_PKT_OK);
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
}
