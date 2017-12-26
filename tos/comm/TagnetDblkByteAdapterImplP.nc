/**
 * Copyright (c) 2017 Daniel J. Maltbie
 * All rights reserved.
 *
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

#include <Tagnet.h>
#include <TagnetAdapter.h>

generic module TagnetDblkByteAdapterImplP (int my_id) @safe() {
  uses interface  TagnetMessage   as  Super;
  uses interface  TagnetAdapter<tagnet_dblk_bytes_t> as Adapter;
  uses interface  TagnetName      as  TName;
  uses interface  TagnetHeader    as  THdr;
  uses interface  TagnetPayload   as  TPload;
  uses interface  TagnetTLV       as  TTLV;
}
implementation {
  enum { my_adapter_id = unique(UQ_TAGNET_ADAPTER_LIST) };

  event bool Super.evaluate(message_t *msg) {
    tagnet_dblk_bytes_t db       = {0,0,0,0,0,0,0};
    uint32_t           ln        = 0;
    tagnet_tlv_t      *name_tlv  = (tagnet_tlv_t *)tn_name_data_descriptors[my_id].name_tlv;
    tagnet_tlv_t      *file_tlv  = call TName.this_element(msg);
    tagnet_tlv_t      *iota_tlv;
    tagnet_tlv_t      *count_tlv;
    uint32_t           usable;

    nop();
    nop();                       /* BRK */
    if (call TTLV.eq_tlv(name_tlv, file_tlv)) {
      tn_trace_rec(my_id, 1);
      switch (call THdr.get_message_type(msg)) {     // process message type
        case TN_GET:
          db.action = DBLK_GET_DATA;
          db.file = call TTLV.tlv_to_integer(file_tlv);  // zzz not used yet
          iota_tlv  = call TName.next_element(msg);
          if ((iota_tlv) && (call TTLV.get_tlv_type(iota_tlv) == TN_TLV_OFFSET)) {
            db.iota = call TTLV.tlv_to_offset(iota_tlv);
          }
          count_tlv = call TName.next_element(msg);
          if ((count_tlv) && (call TTLV.get_tlv_type(count_tlv) == TN_TLV_SIZE)) {
            db.count = call TTLV.tlv_to_size(count_tlv);
          }
          call TPload.reset_payload(msg);            // params have been extracted
          call THdr.set_response(msg);
          call THdr.set_error(msg, TE_PKT_OK);
          tn_trace_rec(my_id, 2);
          usable = call TPload.bytes_avail(msg);
          usable -=  (4 * 6);                        // reserve four integers for rtn vars
          if (usable < db.count) ln = usable;        // ln = min(db.count, unused);
          else                   ln = db.count;
          if (call Adapter.get_value(&db, &ln)) {
            call TPload.add_offset(msg, db.iota);
            if (db.count) call TPload.add_size(msg, db.count);
            if (db.error) call TPload.add_error(msg, db.error);
            if (db.delay) call TPload.add_delay(msg, db.delay);
            if ( ln > 0 ) call TPload.add_block(msg, db.block, ln);
            return TRUE;
          }
          if (db.error) {
            if (db.iota) call TPload.add_offset(msg, db.iota);
            call TPload.add_error(msg, db.error);
            return TRUE;
          }
          break;
        case TN_HEAD:
          // return current size of dblk region, current file position,
          // and last update time
          call TPload.reset_payload(msg);                // no params
          call THdr.set_response(msg);
          call THdr.set_error(msg, TE_PKT_OK);
          db.action = DBLK_GET_ATTR;
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
          break;
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
    } else {
//      panic();
    }
  }

  event void Super.add_value_tlv(message_t* msg) {
    tagnet_dblk_bytes_t     v;
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
