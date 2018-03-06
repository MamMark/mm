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

generic module TagnetNamePollImplP(int my_id) @safe() {
  uses interface     TagnetMessage  as  Super;
  provides interface TagnetAdapter<int32_t>  as  Adapter;
  uses interface     TagnetName     as  TName;
  uses interface     TagnetHeader   as  THdr;
  uses interface     TagnetPayload  as  TPload;
  uses interface     TagnetTLV      as  TTLV;
}
implementation {
  enum { my_adapter_id = unique(UQ_TAGNET_ADAPTER_LIST) };

  int32_t poll_count = 0;

  command bool Adapter.get_value(int32_t *t, uint8_t *l) {
    nop();
    nop();
    *t = poll_count;
    *l = sizeof(int32_t);
    return TRUE;
  }

  event bool Super.evaluate(message_t *msg) {
    tagnet_tlv_t    *name_tlv = (tagnet_tlv_t *)tn_name_data_descriptors[my_id].name_tlv;
    tagnet_tlv_t    *help_tlv = (tagnet_tlv_t *)tn_name_data_descriptors[my_id].help_tlv;
    tagnet_tlv_t    *this_tlv = call TName.this_element(msg);
    tagnet_tlv_t    *next_tlv = call TName.next_element(msg);

    nop();
    nop();

    call THdr.set_response(msg); // zzz need to move inside name match
    if ((next_tlv == NULL) &&                       // end of name and me == this
        (call TTLV.eq_tlv(name_tlv, this_tlv))) {
      tn_trace_rec(my_id, 1);
      poll_count++;
      call TPload.reset_payload(msg);
      call THdr.set_error(msg, TE_PKT_OK);
      switch (call THdr.get_message_type(msg)) {    // process packet type
        case TN_POLL:
          call TPload.add_integer(msg, poll_count);  // zzz need to add the real value here
          tn_trace_rec(my_id, 2);
          return TRUE;
        case TN_HEAD:
          call TPload.add_tlv(msg, help_tlv);
          tn_trace_rec(my_id, 3);
          return TRUE;
        default:
          break;
      }
    }
    call THdr.set_error(msg, TE_PKT_NO_MATCH);
    tn_trace_rec(my_id, 255);
    return FALSE;                                  // no match, do nothing
  }

  event void Super.add_name_tlv(message_t* msg) {
    uint8_t       s;
    tagnet_tlv_t    *name_tlv = (tagnet_tlv_t *)tn_name_data_descriptors[my_id].name_tlv;

    s = call TPload.add_tlv(msg, name_tlv);
    if (s) {
      call TPload.next_element(msg);
    } else {
//      panic();
    }
  }

  event void Super.add_value_tlv(message_t* msg) {
    uint8_t       s;

    s = call TPload.add_integer(msg, 0);
    if (s) {
      call TPload.next_element(msg);
    } else {
//      panic();
    }
  }

  event void Super.add_help_tlv(message_t* msg) {
    uint8_t       s;
    tagnet_tlv_t    *help_tlv = (tagnet_tlv_t *)tn_name_data_descriptors[my_id].help_tlv;

    s = call TPload.add_tlv(msg, help_tlv);
    if (s) {
      call TPload.next_element(msg);
    } else {
//      panic();
    }
  }
}
