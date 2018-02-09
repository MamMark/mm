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
 * checkum. The IM.alloc_abort() is called with checksum failure.
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
  uint16_t           s_buf;        // index of next byte to write
  uint16_t           e_buf;        // index of last byte to write
  image_ver_t        version;      // version of image being loaded
  uint32_t           offset;       // current offset expected
  uint32_t           img_len;      // length of image being loaded
  uint32_t           img_chk;      // checksum of image being loaded
  bool               checksum_good;// calculated correct checksum
} ia_cb_t;

/* initializes to zero which is also FALSE */
ia_cb_t             ia_cb;

/*
 * need enough buffer to hold vector table, image info, and any other data
 * that came through with the last piece of image info.  full message_t is a
 * little bit of overkill but not by much.
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
    if (err == TE_BUSY)
      call TPload.add_error(msg, EALREADY);
    else if (err == TE_UNSUPPORTED)
      call TPload.add_error(msg, EINVAL);
    return TRUE;
  }


  /*
   * do_write: hand data from the IA (image_adapter) to the IM (image_manager).
   *
   * input: msg         pointer to the incoming msg, we will modify this
   *                    msg for the reply.  Will be updated with new_offset
   *        dptr        pointer to incoming bytes that need to be moved to
   *                    the IM.
   *        dlen        how many bytes.
   *
   * dptr may be NULL, from the ia_buf, or from the incoming message.
   *
   *    NULL:   still accumulating the first block of data.  We need enough to
   *            look at the image_info.  Just let the source know we have gotten
   *            the bytes we have seen so far.
   *
   *    ia_buf: dptr points into the ia_buf.  Either we are working on writing
   *            the first block of data.  Or we are doing a partial (a incoming
   *            message wasn't completely consumed by the IM, and the remainder
   *            is in the ia_buf).
   *
   *    msg:    dptr points into the incoming message buffer.  New data that
   *            needs to be consumed.
   *
   */
  bool do_write(message_t *msg, uint8_t *dptr, uint32_t dlen) {
    uint32_t         dleft;
    int              i;

    tn_trace_rec(my_id, 20);
    call THdr.set_error(msg, TE_PKT_OK);
    dleft = 0;
    if (dptr) {
      nop();                                /* BRK */
      tn_trace_rec(my_id, 21);
      dleft = call IM.write(dptr, dlen);    // initiate write to IM
      if (dleft) {                          // copy leftovers to ia_buf
        /*
         * only copy if we need to save what is coming from the incoming msg
         * it didn't get copied all the way out.  so must wait for the
         * write_complete before finishing the consumption of the incoming
         * bytes.  In the meantime, we must stash the remaining bytes
         * in ia_buf until then.
         */
        if (dptr >= ia_buf && dptr < &ia_buf[sizeof(ia_buf)]) {
          ia_cb.s_buf = dlen - dleft;
          ia_cb.e_buf = dlen;
        } else {
          /*
           * left over bytes from the incoming message, save them
           * in ia_buf for the write_continue.
           */
          ia_cb.s_buf = 0;
          ia_cb.e_buf = dleft;
          for (i = 0; i < dleft; i++)
            ia_buf[i] = dptr[dlen-dleft+i];
        }
        tn_trace_rec(my_id, 22);
      }
    }

    /*
     * dleft is zero, all of the last pieces have gone out to IM.
     */
    if (ia_cb.eof && !dleft) {
      tn_trace_rec(my_id, 23);
      call IM.finish();                 // finish if no data pending
    }
    call THdr.set_response(msg);
    call TPload.reset_payload(msg);
    nop();                              /* BRK */
    call TPload.add_offset(msg, ia_cb.offset);
    if (ia_cb.eof)
      call TPload.add_eof(msg);
    tn_trace_rec(my_id, 0xef);
    return TRUE;
  }

  event __attribute__((optimize("O0"))) bool Super.evaluate(message_t *msg) {
//  event bool Super.evaluate(message_t *msg) {
    tagnet_tlv_t    *name_tlv = (tagnet_tlv_t *)tn_name_data_descriptors[my_id].name_tlv;
    tagnet_tlv_t    *help_tlv = (tagnet_tlv_t *)tn_name_data_descriptors[my_id].help_tlv;
    tagnet_tlv_t    *this_tlv = call TName.this_element(msg);
    tagnet_tlv_t    *version_tlv;
    image_ver_t     *version;
    tagnet_tlv_t    *offset_tlv;
    uint32_t         offset = 0;
    tagnet_tlv_t    *eof_tlv = call TPload.first_element(msg);
    uint32_t         dlen = 0;
    uint8_t         *dptr = NULL;
    error_t          err;
    uint8_t          ste[1];    /* just to be clear, a very small array :-) */
    image_dir_slot_t *dirp;
    int              i;

    nop();
    nop();                                          /* BRK */
    if (call TTLV.eq_tlv(name_tlv, this_tlv)) {     //  me == this
      version_tlv = call TName.next_element(msg);
      offset_tlv = call TName.next_element(msg);
      tn_trace_rec(my_id, 1);
      switch (call THdr.get_message_type(msg)) {    // process packet type
        case TN_GET:
          tn_trace_rec(my_id, 2);
          if (call IMD.dir_coherent()) {            // image manager directory is stable
            call TPload.reset_payload(msg);
            call THdr.set_response(msg);
            call THdr.set_error(msg, TE_PKT_OK);
            if ((version_tlv) && (call TTLV.get_tlv_type(version_tlv) == TN_TLV_VERSION)) {
              version = call TTLV.tlv_to_version(version_tlv);
              dirp = call IMD.dir_find_ver(version); // get image info for specific version
              if (dirp) {
                call TPload.add_version(msg, &dirp->ver_id);
                ste[0] = call IMD.slotStateLetter(dirp->slot_state);
                call TPload.add_string(msg, &ste, 1);
              }
            } else {                                // get image info for all versions
              nop();                                /* BRK */
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
          } else {
            tn_trace_rec(my_id, 4);
            return do_reject(msg, TE_BUSY);
          }
          break;

        case TN_DELETE:
          tn_trace_rec(my_id, 5);
          if (call IMD.dir_coherent()) {            // image manager directory is stable
            call TPload.reset_payload(msg);
            call THdr.set_response(msg);
            call THdr.set_error(msg, TE_PKT_OK);
            if ((version_tlv) && (call TTLV.get_tlv_type(version_tlv) == TN_TLV_VERSION)) {
              version = call TTLV.tlv_to_version(version_tlv);
              dirp = call IMD.dir_find_ver(version); // get image info for specific version
              if (dirp) {
                call TPload.add_version(msg, &dirp->ver_id);
                ste[0] = call IMD.slotStateLetter(dirp->slot_state);
                call TPload.add_string(msg, &ste, 1);
              }
              if (call IM.delete(version) == SUCCESS) {         // delete this version
                tn_trace_rec(my_id, 6);
                return TRUE;
              }
            }
            tn_trace_rec(my_id, 7);
            return do_reject(msg, TE_UNSUPPORTED);
          } else
            return do_reject(msg, TE_BUSY);
          break;

        case TN_PUT:
          tn_trace_rec(my_id, 8);
          // must be version in name
          if ((!version_tlv) || (call TTLV.get_tlv_type(version_tlv) != TN_TLV_VERSION))
            return do_reject(msg, TE_BAD_MESSAGE);
          version = call TTLV.tlv_to_version(version_tlv);

          // look for optional offset in name
          if ((offset_tlv) && (call TTLV.get_tlv_type(offset_tlv) == TN_TLV_OFFSET))
            offset = call TTLV.tlv_to_offset(offset_tlv);
          else
            offset = 0;

          // get payload variables (data length and pointer) and/or eof flag
          nop();                                  /* BRK */
          if (call THdr.is_pload_type_raw(msg)) { // msg contains raw data in payload
            dlen = call TPload.get_len(msg);
            dptr = (uint8_t *) eof_tlv;
            eof_tlv = NULL;
          } else if (call TTLV.get_tlv_type(eof_tlv) == TN_TLV_BLK) {
            dptr = call TTLV.tlv_to_string(eof_tlv, &dlen);
            eof_tlv = NULL;
          } else if (call TTLV.get_tlv_type(eof_tlv) != TN_TLV_EOF) {
            return do_reject(msg, TE_BUSY);   // no data or eof found
          }
          if (!eof_tlv)                       // if not already found <eof>
            eof_tlv = call TPload.next_element(msg); // look after data block
          if ((eof_tlv) && (call TTLV.get_tlv_type(eof_tlv) == TN_TLV_EOF))
            ia_cb.eof = TRUE;                 // eof found
          else
            ia_cb.eof = FALSE;

          // continue processing PUT msgs if in progress
          tn_trace_rec(my_id, 9);
          if (ia_cb.in_progress) {
            if ((ia_cb.eof) || ((offset_tlv) && (ia_cb.offset == offset))) {
              /* end of file or expected offset matches */
              nop();                          /* BRK */
              if (!ia_cb.e_buf) {
                ia_cb.offset += dlen;         /* consume new incoming */
                return do_write(msg, dptr, dlen);
              }
            }
            if ((!offset_tlv) || (offset == 0)) {
              call IM.alloc_abort();          /* starting over */
            }
          }

          /* look for new image load request
           * offset=0 or no offset_tlv means start again from beginning
           * The image_info header needs to be examined for version,
           * length and checksum. The header is embedded in the image
           * data and located at byte 0x140 in the image. Note that data
           * from multiple messages may need to be accumulated before
           * the image_info structure can be examined.
           */
          if ((offset_tlv) && (offset != 0)) { // continue accumulating
            /* make sure this PUT for same version */
            if (!call IMD.verEqual(version, &ia_cb.version)) {
              tn_trace_rec(my_id, 10);
              break;                          // ignore msg if mismatch
            }
          } else {                            // start accumulating
            nop();                            /* BRK */
            call IMD.setVer(version, &ia_cb.version);
            ia_cb.e_buf = 0;
            ia_cb.offset = 0;
            tn_trace_rec(my_id, 11);
          }

          if (dptr && dlen) {                 // copy msg data to ia_buf
            for (i = 0; i < dlen; i++)
              ia_buf[ia_cb.e_buf + i] = dptr[i];
            ia_cb.e_buf += dlen;
          }

          // check to see if enough data received to verify image info
          nop();                        /* BRK */
          tn_trace_rec(my_id, 12);
          if (ia_cb.e_buf >= IMAGE_MIN_SIZE) {
            nop();                      /* BRK */
            dptr = ia_buf;
            dlen = ia_cb.e_buf;
            // reset e_buf to force startover if fail to begin image load
            ia_cb.e_buf = 0;

            // look for valid image info
            if (!get_info(version, dptr, dlen)) {
              tn_trace_rec(my_id, 13);
              return do_reject(msg, TE_BAD_MESSAGE);
            }

            // zzz verify checksum, do_reject()

            // allocate new image and write first data
            if ((err = call IM.alloc(&ia_cb.version)) == 0) {
              ia_cb.in_progress = TRUE;       // mark image load now in progress
              ia_cb.offset = dlen;
              return do_write(msg, dptr, dlen);
            }
            tn_trace_rec(my_id, 14);
            return do_reject(msg, TE_BAD_MESSAGE);  // failed allocate
          }

          /* still less than IMAGE_MIN_SIZE, just accumulate */
          if (ia_cb.eof) {                     // eof already, image too short
            tn_trace_rec(my_id, 15);
            return do_reject(msg, TE_BAD_MESSAGE);
          }
          ia_cb.offset = ia_cb.e_buf;               // always what we've seen so far
          return do_write(msg, NULL, dlen);         // just acknowledge PUT
          break;

        case TN_HEAD:
          call THdr.set_response(msg);
          call THdr.set_error(msg, TE_PKT_OK);
          call TPload.reset_payload(msg);
          call TPload.add_tlv(msg, help_tlv);
          tn_trace_rec(my_id, 16);
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
      return;
    }
    ia_cb.s_buf = ia_cb.e_buf = 0;
    if ((dleft == 0) && ia_cb.eof)
      call IM.finish();
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
