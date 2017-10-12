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

#include <TagnetTLV.h>
#include <image_info.h>

generic module TagnetActiveAdapterImplP (int my_id) @safe() {
  uses interface  TagnetMessage   as  Super;
  uses interface  TagnetName      as  TName;
  uses interface  TagnetHeader    as  THdr;
  uses interface  TagnetPayload   as  TPload;
  uses interface  TagnetTLV       as  TTLV;
  uses interface  ImageManager    as  IM;
  uses interface ImageManagerData as  IMD;
  uses interface  OverWatch       as  OW;
}
implementation {
  enum { my_adapter_id = unique(UQ_TAGNET_ADAPTER_LIST) };

  event bool Super.evaluate(message_t *msg) {
    tagnet_tlv_t    *name_tlv = (tagnet_tlv_t *)tn_name_data_descriptors[my_id].name_tlv;
    tagnet_tlv_t    *this_tlv = call TName.this_element(msg);
    tagnet_tlv_t    *next_tlv = call TName.next_element(msg);
    image_dir_slot_t    *dirp;
    image_ver_t         *verp;
    uint8_t            ste[1];

    if (call TTLV.eq_tlv(name_tlv, this_tlv)) {   //  my tlv = this
      tn_trace_rec(my_id, 1);
      call THdr.set_response(msg);
      call THdr.set_error(msg, TE_PKT_OK);
      call TPload.reset_payload(msg);
      switch (call THdr.get_message_type(msg)) {      // process message type

        case TN_PUT:
          tn_trace_rec(my_id, 2);
          if ((next_tlv) && (call TTLV.get_tlv_type(next_tlv) == TN_TLV_VERSION)) {
            verp = call TTLV.tlv_to_version(next_tlv);
            if (call IM.dir_set_active(verp) == SUCCESS)
              return TRUE;
          }
          call THdr.set_error(msg, TE_UNSUPPORTED);
          return TRUE;

        case TN_GET:
          tn_trace_rec(my_id, 3);
          dirp = call IMD.dir_get_active();
          if (dirp) {
            call TPload.add_version(msg, &dirp->ver_id);
            ste[0] = call IMD.slotStateLetter(dirp->slot_state);
            call TPload.add_string(msg, &ste[0], 1);
          }
          return TRUE;

        default:
          break;
      }
      call THdr.set_error(msg, TE_PKT_NO_MATCH);
    }
    tn_trace_rec(my_id, 255);
    return FALSE;
  }

  event   void    IM.dir_eject_active_complete() { }

  event   void    IM.dir_set_active_complete() {
    // ??? flush i/o now
    call OW.install();
  }

  event   void    IM.dir_set_backup_complete() { }

  event   void    IM.finish_complete() { }

  event   void    IM.write_continue() { }

  event   void    IM.delete_complete() { }

  event void Super.add_name_tlv(message_t* msg) {
    tagnet_tlv_t    *name_tlv = (tagnet_tlv_t *)tn_name_data_descriptors[my_id].name_tlv;

    call TPload.add_tlv(msg, name_tlv);
  }

  event void Super.add_value_tlv(message_t* msg) {
    image_dir_slot_t    *dirp;
    uint8_t            ste[1];

    dirp = call IMD.dir_get_active();
    if (dirp) {
      call TPload.add_version(msg, &dirp->ver_id);
      ste[0] = call IMD.slotStateLetter(dirp->slot_state);
      call TPload.add_string(msg, &ste[0], 1);
    }
  }

  event void Super.add_help_tlv(message_t* msg) {
    uint8_t          ste[1];

    tagnet_tlv_t    *help_tlv = (tagnet_tlv_t *)tn_name_data_descriptors[my_id].help_tlv;
    call TPload.add_tlv(msg, help_tlv);
  }
}
