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

generic module TagnetSysExecAdapterImplP (int my_id) @safe() {
  uses interface  TagnetMessage        as  Super;
  uses interface  TagnetSysExecAdapter as  Adapter;
  uses interface  TagnetName           as  TName;
  uses interface  TagnetHeader         as  THdr;
  uses interface  TagnetPayload        as  TPload;
  uses interface  TagnetTLV            as  TTLV;
}
implementation {
  enum { my_adapter_id = unique(UQ_TAGNET_ADAPTER_LIST) };

  event bool Super.evaluate(message_t *msg) {
    tagnet_tlv_t    *name_tlv = (tagnet_tlv_t *)tn_name_data_descriptors[my_id].name_tlv;
    tagnet_tlv_t    *this_tlv = call TName.this_element(msg);
    tagnet_tlv_t    *next_tlv;
    image_ver_t      ver_id, *verp;
    uint8_t          ste[1];


    call THdr.set_response(msg);
    if (call TTLV.eq_tlv(name_tlv, this_tlv)) {  // me == this
      tn_trace_rec(my_id, 1);
      call TPload.reset_payload(msg);
      call THdr.set_error(msg, TE_PKT_OK);
      switch (call THdr.get_message_type(msg)) {      // process message type

        case TN_GET:
          tn_trace_rec(my_id, 2);
          call Adapter.get_version(&ver_id);
          call TPload.add_version(msg, &ver_id);
          ste[0] = call Adapter.get_state();
          call TPload.add_string(msg, &ste[0], 1);
          return TRUE;

        case TN_PUT:
          tn_trace_rec(my_id, 3);
          next_tlv = call TName.next_element(msg);
          if ((next_tlv) && (call TTLV.get_tlv_type(next_tlv) == TN_TLV_VERSION)) {
            verp = call TTLV.tlv_to_version(next_tlv);
            if ((verp) && (call Adapter.set_version(verp) == SUCCESS))
              return TRUE;
          }
          call THdr.set_error(msg, TE_UNSUPPORTED);
          return TRUE;
          break;

        case TN_HEAD:
          // return current size of file region, current file position,
          // and last update time
          // zzz needs to be fixed up when image directory holds size
          // and creation date
          call TPload.reset_payload(msg);                // no params
          call THdr.set_response(msg);
          call THdr.set_error(msg, TE_PKT_OK);
          call TPload.add_offset(msg, 0);
          call TPload.add_size(msg, 0);
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
    int                     s;
    tagnet_tlv_t    *name_tlv = (tagnet_tlv_t *)tn_name_data_descriptors[my_id].name_tlv;

    s = call TPload.add_tlv(msg, name_tlv);
    if (s) {
      call TPload.next_element(msg);
    }
  }

  event void Super.add_value_tlv(message_t* msg) {
    image_ver_t             ver_id;
    uint8_t                 ste[1];

    if (call Adapter.get_version(&ver_id) == SUCCESS) {
      call TPload.add_version(msg, &ver_id);
      ste[0] = call Adapter.get_state();
      call TPload.add_string(msg, &ste[0], 1);
//      call TPload.next_element(msg);
    }
  }

  event void Super.add_help_tlv(message_t* msg) {
    int                     s;
    tagnet_tlv_t    *help_tlv = (tagnet_tlv_t *)tn_name_data_descriptors[my_id].help_tlv;

    s = call TPload.add_tlv(msg, help_tlv);
    if (s) {
      call TPload.next_element(msg);
    }
  }
}
