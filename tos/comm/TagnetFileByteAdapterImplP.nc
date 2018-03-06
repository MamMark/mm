/**
 * @Copyright (c) 2017 Daniel J. Maltbie
 * @Copyright (c) 2017-2018 Daniel J. Maltbie, Eric B. Decker
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
 * @author Eric B. Decker <cire831@gmail.com>
 */

#include <Tagnet.h>
#include <TagnetAdapter.h>

generic module TagnetFileByteAdapterImplP (int my_id) @safe() {
  uses interface  TagnetMessage   as  Super;
  uses interface  TagnetAdapter<tagnet_file_bytes_t> as Adapter;
  uses interface  TagnetName      as  TName;
  uses interface  TagnetHeader    as  THdr;
  uses interface  TagnetPayload   as  TPload;
  uses interface  TagnetTLV       as  TTLV;
}
implementation {
  enum { my_adapter_id = unique(UQ_TAGNET_ADAPTER_LIST) };

  /*
   * given an incoming msg, extract various msg parameters
   * in particular, context, iota, and count.
   */
  void get_params(tagnet_file_bytes_t *db, message_t *msg) {
    tagnet_tlv_t    *a_tlv;
    uint8_t          i;

    for (i = 0; i < 3; i++) {
      a_tlv  = call TName.next_element(msg);
      if (a_tlv == NULL) break;

      switch (call TTLV.get_tlv_type(a_tlv)) {
        case TN_TLV_INTEGER:
          db->context = call TTLV.tlv_to_integer(a_tlv);
          break;
        case TN_TLV_OFFSET:
          db->iota = call TTLV.tlv_to_offset(a_tlv);
          break;
        case TN_TLV_SIZE:
          db->count = call TTLV.tlv_to_size(a_tlv);
          break;
        default:
          break;
      }
    }
  }


  /*
   * Using the passed in context db, extract various
   * attributes and lay down in an outgoing msg.
   */
  void set_params(tagnet_file_bytes_t *db, message_t *msg, uint32_t ln) {
    call TPload.add_offset(msg, db->iota);
    if (db->count) call TPload.add_size(msg, db->count);
    if (db->error) call TPload.add_error(msg, db->error);
    if (db->delay) call TPload.add_delay(msg, db->delay);
    if ( ln > 0 )  call TPload.add_block(msg, db->block, ln);
  }


  event bool Super.evaluate(message_t *msg) {
    tagnet_file_bytes_t db       = {0,0,0,0,0,0,0};
    uint32_t           ln        = 0;
    tagnet_tlv_t      *name_tlv  = (tagnet_tlv_t *)tn_name_data_descriptors[my_id].name_tlv;
    tagnet_tlv_t      *my_tlv    = call TName.this_element(msg);
    uint32_t           usable;
    tagnet_tlv_t      *data_tlv;
    uint8_t           *datap;

    nop();
    nop();                       /* BRK */
    if (call TTLV.eq_tlv(name_tlv, my_tlv)) {
      tn_trace_rec(my_id, 1);
      switch (call THdr.get_message_type(msg)) {     // process message type
        case TN_GET:
          db.action = FILE_GET_DATA;
          get_params(&db, msg);
          call TPload.reset_payload(msg);            // params have been extracted
          call THdr.set_response(msg);
          call THdr.set_error(msg, TE_PKT_OK);
          tn_trace_rec(my_id, 2);
          usable = call TPload.bytes_avail(msg);
          usable -=  (4 * 6);                        // reserve four integers for rtn vars
          if (usable < db.count) ln = usable;        // ln = min(db.count, unused);
          else                   ln = db.count;
          if (call Adapter.get_value(&db, &ln)) {
            set_params(&db, msg, ln);
            return TRUE;
          }

          /*
           * Adapter returned FALSE so only return response if non-zero error
           */
          if (db.error) {
            if (db.iota) call TPload.add_offset(msg, db.iota);
            call TPload.add_error(msg, db.error);
            return TRUE;
          }
          break;                        /* don't respond, see below */

        case TN_PUT:
          tn_trace_rec(my_id, 2);
          db.action = FILE_SET_DATA;
          get_params(&db, msg);
          data_tlv = call TPload.first_element(msg);
          if (call THdr.is_pload_type_raw(msg)) {
            datap = (uint8_t *) data_tlv;
            ln = call TPload.get_len(msg);
          } else
            datap = call TTLV.tlv_to_block(data_tlv, &ln);
          db.block = datap;
          call TPload.reset_payload(msg);
          call THdr.set_response(msg);
          call THdr.set_error(msg, TE_PKT_OK);
          if (call Adapter.set_value(&db, &ln)) {
            set_params(&db, msg, ln);
            return TRUE;
          }

          /*
           * Adapter returned FALSE so only return response if non-zero error
           */
          if (db.error) {
            if (db.iota) call TPload.add_offset(msg, db.iota);
            call TPload.add_error(msg, db.error);
            return TRUE;
          }
          break;                        /* don't respond, see below */

        case TN_HEAD:
          // return current size of file region, current file position,
          // and last update time
          call TPload.reset_payload(msg);                // no params
          call THdr.set_response(msg);
          call THdr.set_error(msg, TE_PKT_OK);
          db.action = FILE_GET_ATTR;
          if (call Adapter.get_value(&db, &ln)) {
            call TPload.add_offset(msg, db.iota);
            call TPload.add_size(msg, db.count);
            return TRUE;
          }
          if (db.error) {
            if (db.iota) call TPload.add_offset(msg, db.iota);
            call TPload.add_error(msg, db.error);
            return TRUE;
          }
          break;                        /* don't respond, see below */
        default:
          break;                        /* don't respond, see below */
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
    } else {
//      panic();
    }
  }

  event void Super.add_value_tlv(message_t* msg) {
    tagnet_file_bytes_t     v;
    uint32_t                l;

    if (call Adapter.get_value(&v, &l)) {
      nop();
    }
  }

  event void Super.add_help_tlv(message_t* msg) {
    int                     s;
    tagnet_tlv_t    *help_tlv = (tagnet_tlv_t *)tn_name_data_descriptors[my_id].help_tlv;

    s = call TPload.add_tlv(msg, help_tlv);
    if (s) {
      call TPload.next_element(msg);
    } else {
//      panic();
    }
  }
}
