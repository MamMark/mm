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

#include <TagnetTLV.h>

generic module TagnetIntegerAdapterImplP (int my_id) @safe() {
  uses interface  TagnetMessage   as  Super;
  uses interface  TagnetAdapter<int32_t> as Adapter;
  uses interface  TagnetName      as  TName;
  uses interface  TagnetHeader    as  THdr;
  uses interface  TagnetPayload   as  TPload;
  uses interface  TagnetTLV       as  TTLV;
}
implementation {
  enum { my_adapter_id = unique(UQ_TAGNET_ADAPTER_LIST) };

  event bool Super.evaluate(message_t *msg) {
    int32_t                 v = 0;
    uint32_t               ln = 0;
    tagnet_tlv_t    *name_tlv = (tagnet_tlv_t *)tn_name_data_descriptors[my_id].name_tlv;
    tagnet_tlv_t    *this_tlv = call TName.this_element(msg);

    if (call TTLV.eq_tlv(name_tlv, this_tlv)) {
      tn_trace_rec(my_id, 1);
      call THdr.set_error(msg, TE_PKT_OK);
      switch (call THdr.get_message_type(msg)) {      // process message type
        case TN_GET:
          tn_trace_rec(my_id, 2);
          call TPload.reset_payload(msg);
          if (call Adapter.get_value(&v, &ln)) {
            call TPload.add_integer(msg, v);
            call TPload.add_error(msg, EODATA);
          } else {
            tn_trace_rec(my_id, 3);
            call TPload.add_error(msg, EINVAL);
          }
          call THdr.set_response(msg);
          return TRUE;

        case TN_HEAD:
          tn_trace_rec(my_id, 4);
          call TPload.reset_payload(msg);
          call TPload.add_size(msg, sizeof(v));    // value is used for file size
          call THdr.set_response(msg);
          return TRUE;

        default:
          break;
      }
    }
    call THdr.set_error(msg, TE_PKT_NO_MATCH);
    tn_trace_rec(my_id, 255);
    return FALSE;
  }

  event void Super.add_name_tlv(message_t* msg) {
    tagnet_tlv_t    *name_tlv = (tagnet_tlv_t *)tn_name_data_descriptors[my_id].name_tlv;

    call TPload.add_tlv(msg, name_tlv);
  }

  event void Super.add_value_tlv(message_t* msg) {
    int32_t                 v;
    uint32_t                ln;

    if (call Adapter.get_value(&v, &ln)) {
      call TPload.add_integer(msg, v);
    }
    // zzz else ?
  }

  event void Super.add_help_tlv(message_t* msg) {
    tagnet_tlv_t    *help_tlv = (tagnet_tlv_t *)tn_name_data_descriptors[my_id].help_tlv;
    call TPload.add_tlv(msg, help_tlv);
  }
}
