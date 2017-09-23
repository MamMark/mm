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

/**
 * TagNet Image Adapter
 *
 * Provides network accessibility to the tag image store. A number
 * of operations can be performed by the Image Adapter:
 *
 * OPERATION
 *
 *   PUT /tag/sd/<nid>/0/img/<version>[/<offset>]:<block>[/<eof>]
 *
 * This operation performs the image load operation. The host issues
 * PUT requests to the Tag to load a new image by writing parts
 * of the image in successive, sequentially ordered blocks of data.
 * The <version> specifies which image is being loaded. The <offset>
 * provides the byte position in the image where this block of data
 * resides. The length of the block is derived from the structure
 * holding it. The payload of the PUT message contains the data and
 * optionally the <eof> tlv. The payload may be formatted as either
 * a raw block, in which the entire payload is data without any tlv,
 * or the data can be in a <block> tlv which indicates the length of
 * the data. The <eof> tlv indicates the last PUT of data and can
 * either follow a data <block> or it can be in the message by
 * itself.
 * Rules for handling a PUT to write data are:
 * - first see that Image Adapter has no pending data to write
 *   - check to see if image load is already in progress
 *     - check if <offset> matches expected
 *       - issue IM write
 *       - if bytes_left then copy remaining to ia_buf
 *       - check for <eof> in msg
 *   - else check to see if this is the first PUT (<offset=0>)
 *     - check <version> in message with version in image_info
 *       - call IM alloc to start the image load into SD
 *       - issue IM write
 *       - if bytes_left then copy remaining to ia_buf
 *       - check for <eof> in msg
 *   - if eof then verify checksum and IM finish or abort
 *
 * Image Adapter may have pending data in the ia_buf waiting to be
 * written out. IM write_continue will issue a new IM write with
 * remaining data. This repeats until IM write returns zero.
 * All data has been written when the s_buf == e_buf. Further
 * PUTs can now be processed.
 *
 *   GET /tag/sd/<nid>/0/img[/<version>]
 *
 * This operation gets information about currently stored images.
 * The <version> specifies which image for which information is
 * requested. If the <version> is omitted, then information about
 * all available images is returned.
 *
 * BUFFERING
 *
 * Image adapter maintains an intermediate buffer to hold imcoming
 * data while Image Manager is writing to disk (a non-zero return from
 * IM.write()). Data from the message that isn't accepted by IM will
 * be copied to this buffer. This allows the message acknowledgement
 * to be sent immediately. Upon IM.write_continue(), if  buffer is
 * non-empty another write is initiated. Any leftover repeat this
 * cycle.
 * Once all data has been written and the eof tlv detected, the checksum
 * is verified. The IM.finish() is called to finalize a successful
 * checkum. The IM.abort() is called with checksum failure.
 */

#include <message.h>
#include <image_info.h>
#include <image_mgr.h>
#include <Tagnet.h>

/*
 * ia_cb = image adapter control block
 */
typedef struct{
  bool               in_progress;  // currently receiving an image
  bool               eof;          // eof tlv detected
  uint8_t            s_buf;        // index of next byte to write
  uint8_t            e_buf;        // index of last byte to write
  image_ver_t        version;      // version of image being loaded
  uint32_t           offset;       // current offset expected
  uint32_t           img_len;      // length of image being loaded
  uint32_t           img_chk;      // checksum of image being loaded
  uint32_t           img_offset;   // byte offset for next write
  bool               checksum_good;// calculated correct checksum
} ia_cb_t;
ia_cb_t             ia_cb = { FALSE, FALSE, 0, 0};

/*
 * need enough buffer to hold vector table, image info, plus another message
 * worth of data. this allows validation of image info before image manager
 * allocation.
 */
#define IA_BUF_SIZE (sizeof(message_t) + IMAGE_META_OFFSET + sizeof(image_info_t))
uint8_t             ia_buf[IA_BUF_SIZE] __attribute__((aligned(4)));

generic module TagnetImageAdapterImplP(int my_id) @safe() {
  uses interface     TagnetMessage  as  Super;
  uses interface     TagnetName     as  TName;
  uses interface     TagnetHeader   as  THdr;
  uses interface     TagnetPayload  as  TPload;
  uses interface     TagnetTLV      as  TTLV;
  uses interface     ImageManager   as  IM;
  uses interface   ImageManagerData as  IMD;
}
implementation {
  enum { my_adapter_id = unique(UQ_TAGNET_ADAPTER_LIST) };

  bool verify_checksum() { return TRUE; }

  bool get_info(image_ver_t *version, uint8_t *dptr, uint32_t dlen) { // get image info
    image_info_t    *infop = NULL;

    if ((dptr) && (dlen > (IMAGE_META_OFFSET + sizeof(image_info_t))))
      infop = (image_info_t *) &dptr[IMAGE_META_OFFSET];
    if ((infop) && (call IMD.verEqual(&infop->ver_id, version))) { // sanity check
      call IMD.setVer(version, &ia_cb.version);
      ia_cb.img_len = infop->image_length;   // save for later
      ia_cb.img_chk = infop->image_chk;
      return TRUE;
    }
    return FALSE;
  }

  /* respond to msg with error */
  bool do_reject(message_t *msg, tagnet_error_t err) {
    call THdr.set_response(msg);
    call THdr.set_error(msg, err);
    call TPload.reset_payload(msg);
    return TRUE;
  }

  /* handle moving data from msg to image manager and  responding to msg */
  bool do_write(message_t *msg, uint8_t *dptr, uint32_t dlen) {
    uint32_t         dleft;
    int              i;

    tn_trace_rec(my_id, 9);
    call THdr.set_error(msg, TE_PKT_OK);
    if (dptr) {
      dleft = call IM.write(dptr, dlen);    // initiate write to IM
      if (dleft) {                          // copy leftovers to ia_buf
        ia_cb.s_buf = 0;
        ia_cb.e_buf = dleft;
        for (i = 0; i < dleft; i++) {
          ia_buf[i] = dptr[dlen-dleft+i];
        }
        tn_trace_rec(my_id, 10);
      }
      ia_cb.offset += dlen;                 // next byte offset to expect
    }
    if (ia_cb.eof) {
      ia_cb.checksum_good = verify_checksum();
      if (ia_cb.checksum_good) {
        if (ia_cb.e_buf == 0)
          call IM.finish();                 // finish if no data pending
        tn_trace_rec(my_id, 11);
      } else {
        call IM.alloc_abort();          // abort is immediate, change state
        ia_cb.in_progress = FALSE;
        ia_cb.eof = FALSE;
        ia_cb.s_buf = ia_cb.e_buf = 0;
        call THdr.set_error(msg, TE_FAILED);
        tn_trace_rec(my_id, 12);
      }
    }
    call THdr.set_response(msg);
    call TPload.reset_payload(msg);
    call TPload.add_offset(msg, ia_cb.offset);
    if (ia_cb.eof)
      call TPload.add_eof(msg);
    tn_trace_rec(my_id, 13);
    return TRUE;
  }

  event __attribute__((optimize("O0"))) bool Super.evaluate(message_t *msg) {
//  event bool Super.evaluate(message_t *msg) {
    tagnet_tlv_t    *name_tlv = (tagnet_tlv_t *)tn_name_data_descriptors[my_id].name_tlv;
    tagnet_tlv_t    *help_tlv = (tagnet_tlv_t *)tn_name_data_descriptors[my_id].help_tlv;
    tagnet_tlv_t    *this_tlv = call TName.this_element(msg);
    tagnet_tlv_t    *version_tlv = call TName.next_element(msg);
    image_ver_t     *version;
    tagnet_tlv_t    *offset_tlv = call TName.next_element(msg);
    uint32_t         offset = 0;
    tagnet_tlv_t    *eof_tlv = call TPload.first_element(msg);
    uint8_t          dlen = 0;
    uint8_t         *dptr = NULL;
    error_t          err;
    uint8_t          ste[1];
    image_dir_slot_t *dirp;
    int              i;

    nop();
    nop();
    if (call TTLV.eq_tlv(name_tlv, this_tlv)) {     //  me == this
      tn_trace_rec(my_id, 1);
      switch (call THdr.get_message_type(msg)) {    // process packet type
        case TN_GET:
          tn_trace_rec(my_id, 2);
          if (call IMD.dir_coherent()) {            // image manager directory is stable
            call TPload.reset_payload(msg);
            call THdr.set_response(msg);
            call THdr.set_error(msg, TE_PKT_OK);
            if ((version_tlv) && (call TTLV.get_tlv_type(version_tlv) != TN_TLV_VERSION)) {
              version = call TTLV.tlv_to_version(version_tlv);
              dirp = call IMD.dir_find_ver(version); // get image info for specific version
              if (dirp) {
                ste[0] = call IMD.slotStateLetter(dirp->slot_state);
                call TPload.add_string(msg, &ste, 1);
              }
            } else {                                // get image info for all versions
              for (i = 0; i < IMAGE_DIR_SLOTS; i++) {
                dirp = call IMD.dir_get_dir(i);
                if (!dirp)
                  break;
                call TPload.add_version(msg, &dirp->ver_id);
                ste[0] = call IMD.slotStateLetter(dirp->slot_state);
                call TPload.add_string(msg, &ste[0], 1);
              }
            }
            tn_trace_rec(my_id, 3);
            return TRUE;
          } else
            return do_reject(msg, TE_BUSY);
          break;

        case TN_PUT:
          tn_trace_rec(my_id, 5);
          // check to see if still writing data from previous PUT
          if ((ia_cb.in_progress) && (ia_cb.e_buf))
            return do_reject(msg, TE_BUSY);

          // must be version in name
          if ((!version_tlv) || (call TTLV.get_tlv_type(version_tlv) != TN_TLV_VERSION))
            return do_reject(msg, TE_BAD_MESSAGE);
          version = call TTLV.tlv_to_version(version_tlv);

          // look for optional offset in name
          offset_tlv = NULL;
          if ((offset_tlv) && (call TTLV.get_tlv_type(offset_tlv) == TN_TLV_OFFSET))
            offset = call TTLV.tlv_to_integer(offset_tlv);

          // get payload variables (data length and pointer) and/or eof flag
          if (call THdr.is_pload_type_raw(msg)) { // msg contains raw data in payload
            dlen = call TPload.get_len(msg);
            dptr = (uint8_t *) eof_tlv;
            eof_tlv = NULL;
          } else if (call TTLV.get_tlv_type(eof_tlv) == TN_TLV_BLK) {
            dlen = 0;
            dptr = call TTLV.tlv_to_string(eof_tlv, &dlen);
            eof_tlv = NULL;
          } else if (call TTLV.get_tlv_type(eof_tlv) != TN_TLV_EOF) {
            return do_reject(msg, TE_BUSY);   // no data or eof found
          }
          if (!eof_tlv)                       // if not already found <eof>
            eof_tlv = call TPload.next_element(msg); // look after data block
          if ((eof_tlv) && (call TTLV.get_tlv_type(eof_tlv) == TN_TLV_EOF))
            ia_cb.eof = TRUE;                 // eof found

          // continue processing PUT msgs if in progress
          tn_trace_rec(my_id, 6);
          if (ia_cb.in_progress) {
            if ((offset_tlv) && (ia_cb.offset == offset))
              return do_write(msg, dptr, dlen); /* expected offset matches */
            else
              break;                          // ignore
          }

          // look for new image load request
          if ((offset_tlv) && (offset != 0)) { // continue accumulating
            /* make sure this PUT for same version */
            if (!call IMD.verEqual(version, &ia_cb.version)) {
              break;                          // ignore msg if mismatch
            }
          } else {                            // start accumulating
            call IMD.setVer(version, &ia_cb.version);
            ia_cb.e_buf = 0;
          }

          if (dptr) {                     // copy msg data to ia_buf
            for (i = 0; i < dlen; i++) {
              ia_buf[ia_cb.e_buf + i] = dptr[i];
            }
            ia_cb.e_buf += dlen;
          }

          // check to see if enough data received to verify image info
          if (ia_cb.e_buf >= IMAGE_MIN_SIZE) {
            tn_trace_rec(my_id, 6);
            dptr = ia_buf;
            dlen = ia_cb.e_buf;
            // reset e_buf to force startover if fail to begin image load
            ia_cb.e_buf = 0;

            // look for valid image info
            if (!get_info(version, dptr, dlen))
              return do_reject(msg, TE_BAD_MESSAGE);

            // allocate new image and write first data
            if ((err = call IM.alloc(&ia_cb.version)) == 0) {
              ia_cb.in_progress = TRUE;       // mark image load now in progress
              if ((eof_tlv) && (call TTLV.get_tlv_type(eof_tlv) == TN_TLV_EOF))
                ia_cb.eof = TRUE;             // eof found (really short file!)
              else
                ia_cb.eof = FALSE;            // start of image load, init eof
              return do_write(msg, dptr, dlen);
            }
            return do_reject(msg, TE_BAD_MESSAGE);  // failed allocate
          }
          if (ia_cb.eof)                      // eof already, image too short
            return do_reject(msg, TE_BAD_MESSAGE);
          return do_write(msg, NULL, 0);      // just acknowledge PUT

          nop();
          break;

        case TN_HEAD:
          call THdr.set_response(msg);
          call THdr.set_error(msg, TE_PKT_OK);
          call TPload.reset_payload(msg);
          call TPload.add_tlv(msg, help_tlv);
          tn_trace_rec(my_id, 14);
          return TRUE;

        default:
          break;
      }
    }
    call THdr.set_response(msg);
    call THdr.set_error(msg, TE_PKT_NO_MATCH);
    tn_trace_rec(my_id, 255);
    return FALSE;
  }

  event   void    IM.delete_complete() { }

  event   void    IM.dir_eject_active_complete() { }

  event   void    IM.dir_set_active_complete() { }

  event   void    IM.dir_set_backup_complete() { }

  event   void    IM.finish_complete() {
    ia_cb.in_progress = FALSE;
    ia_cb.eof = FALSE;
    ia_cb.s_buf = ia_cb.e_buf = 0;
  }

  event   void    IM.write_continue() {
    uint32_t         dleft;

    dleft = call IM.write(&ia_buf[ia_cb.s_buf], ia_cb.e_buf - ia_cb.s_buf);
    if (dleft) {
      ia_cb.s_buf = ia_cb.e_buf - dleft;
    } else {
      ia_cb.s_buf = ia_cb.e_buf = 0;
    }
    if ((dleft == 0) && ia_cb.eof && ia_cb.checksum_good) {
      call IM.finish();
    }
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
