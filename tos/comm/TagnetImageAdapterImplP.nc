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
 *
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
 *   DELETE /tag/sd/<nid>/0/img/<version>
 *
 * This operation deletes the version from the Image Manager storage.
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
  uint16_t           s_buf;        // index of next byte to write
  uint16_t           e_buf;        // index of last byte to write
  bool               eof;          // eof detected but not ack'd
  image_ver_t        version;      // version of image being loaded
  uint32_t           offset;       // current offset expected
  uint32_t           img_len;      // length of image being loaded
  uint32_t           img_chk;      // checksum of image being loaded
  bool               info_good;    // image info is verified
  bool               chk_good;     // calculated correct checksum
} ia_cb_t;

/*
 * put   = parameters received in the put image message
 */
typedef struct {
  image_ver_t        version;      // version in put request
  uint32_t           offset;       // file offset of put
  uint32_t           size;         // total amount being written
  uint32_t           dlen;         // length of put data block
  uint8_t           *dptr;         // ptr to data block
  bool               eof;          // eof flag in put request
} put_params_t;

/* initializes to zero which is also FALSE */
ia_cb_t             ia_cb;
put_params_t        put;

/*
 * need enough buffer to hold vector table, image info, and any other data
 * that came through with the last piece of image info.  full message_t is a
 * little bit of overkill but not by much.
 */
#define IA_BUF_SIZE (sizeof(message_t) + IMAGE_MIN_BASIC)
uint8_t             ia_buf[IA_BUF_SIZE] __attribute__((aligned(4)));
image_info_basic_t  ia_info;

generic module TagnetImageAdapterImplP(int my_id) @safe() {
  uses interface     TagnetMessage  as  Super;
  uses interface     TagnetName     as  TName;
  uses interface     TagnetHeader   as  THdr;
  uses interface     TagnetPayload  as  TPload;
  uses interface     TagnetTLV      as  TTLV;
  uses interface     ImageManager   as  IM;
  uses interface   ImageManagerData as  IMD;
  uses interface                        Panic;
}
implementation {
  enum { my_adapter_id = unique(UQ_TAGNET_ADAPTER_LIST) };

  /*
   * verify_checksum
   */
  bool verify_checksum() { return TRUE; }

  /*
   * verify_image_info
   *          verify that the image being written (the version
   *          in the tagname) is the image we are downloading
   *          (image_info_basic.ver_id)
   *
   * return value:  -1   invalid request
   *                 0   not verified
   *                 1   verified
   */
  int32_t verify_image_info() {
    uint8_t    *pinfo;
    uint32_t    i, ss, se;

    if (ia_cb.info_good) {  // already verified, just don't regress
      if (put.offset < IMAGE_MIN_BASIC) return -1;
      return 1;
    }
    // check if entire data block is before or after image info
    if ((put.offset + put.dlen) < IMAGE_META_OFFSET) return 0;
    if (put.offset >= IMAGE_MIN_BASIC) return -1;
    // extract data slice from block that overlaps with image info
    ss = (put.offset < IMAGE_META_OFFSET) ? IMAGE_META_OFFSET \
                                          : put.offset;
    se = ((put.offset + put.dlen) >= IMAGE_MIN_BASIC) ? IMAGE_MIN_BASIC \
                                          : (put.offset + put.dlen);
    if ((se-ss)>sizeof(ia_info))  // calc check
      call Panic.panic(PANIC_TAGNET, TAGNET_AUTOWHERE, 0, 0, 0, 0);
    pinfo = (uint8_t *) &ia_info;
    for (i = 0; i < se-ss; i++) { // copy slice to the image info struct
      pinfo[i] = put.dptr[(ss-put.offset)+i];
    }
    // check if more bytes needed
    if ((put.offset+put.dlen) < IMAGE_MIN_BASIC) return 0;

    // collection complete, verify image info
    if ((ia_info.ii_sig != IMAGE_INFO_SIG) ||
        (!call IMD.verEqual(&ia_info.ver_id, &ia_cb.version)))
      return -1;
    ia_cb.info_good = TRUE;
    ia_cb.img_len = ia_info.image_length;   // save for later
    ia_cb.img_chk = ia_info.image_chk;
    return 1;
  }

  /*
   * do_reject        respond to msg with error
   */
  bool do_reject(message_t *msg, tagnet_error_t err) {
    call THdr.set_response(msg);
    call TPload.reset_payload(msg);
    call THdr.set_error(msg, TE_PKT_OK);
    call TPload.add_error(msg, err);
    call TPload.add_offset(msg, ia_cb.offset);
    return TRUE;
  }

  /*
   * is_version_set   check to see if version is set
   */
  bool is_version_set(image_ver_t *ver) {
    // any non-zero field make version valid
    if ((ver->build != 0) || (ver->major  != 0) || (ver->minor != 0))
      return TRUE;
    return FALSE;
  }

  /*
   * do_write: hand data from the IA (image_adapter) to the IM (image_manager).
   *
   * input: msg         pointer to the incoming msg, we will modify this
   *                    msg for the reply, including the new_offset
   *
   * The put.dptr points to the incoming message date block.  This is new
   * data that needs to be stored. If we are already writing something, then
   * return EBUSY.
   *
   * if the IM.write() returns a non-zero dleft value, then the remaining
   * data needs to be copied from the msg buffer into a temp buffer so that
   * the msg ack can be returned immediately. If the the temp buffer is
   * already occupied from a previous write msg, then return EBUSY. Image
   * Manager will signal when it is ready for more data.
   *
   */
  bool do_write(message_t *msg) {
    uint32_t         dleft;
    int              i;

    tn_trace_rec(my_id, 01);
    call THdr.set_error(msg, TE_PKT_OK);
    dleft = 0;
    if (put.dptr) {
      dleft = call IM.write(put.dptr, put.dlen); // initiate write to IM
      if (dleft) {                          // copy leftovers to ia_buf
        /*
         * only copy if we need to save what is coming from the incoming msg
         * that didn't get accepted by Image Manager.  So must wait for the
         * IM.write_complete() to finish the consumption of the remaining
         * bytes.  In the meantime, we must stash the remaining bytes
         * in ia_buf until then.
         */
        ia_cb.s_buf = 0;
        ia_cb.e_buf = dleft;
        for (i = 0; i < dleft; i++)
          ia_buf[i] = put.dptr[put.dlen-dleft+i];
        tn_trace_rec(my_id, 02);
      }
      ia_cb.offset += put.dlen;
      /*
       * check for validity of image info by extracting image_info_base
       * from the data stream. Once enough data has been received, the
       * validity of the image_info_base can be verified.
       */
      switch (verify_image_info()) {
        case 0:                           // still collecting
        default:                          // verified
          break;
        case -1:                          // unexpected error
          tn_trace_rec(my_id, 03);
          call IM.alloc_abort();
          ia_cb.in_progress = FALSE;
          return do_reject(msg, EINVAL);
      }
      tn_trace_rec(my_id, 04);
    }

    // handle eof indicator in message
    if (put.eof) {
      ia_cb.eof = TRUE;
      ia_cb.chk_good = verify_checksum();
      /*
       * dleft is zero, all of the last pieces have gone out to IM.
       * can now initiate closing file or aborting. otherwise,
       * finish is initiated or abort is terminated
       */
      if (dleft == 0) {      // finish if no further data to write
        if (ia_cb.chk_good) {
          call IM.finish();
        } else {
          call IM.alloc_abort();          // no wait for abort
          ia_cb.in_progress = FALSE;
        }
      } // else handled in IM.write_continue() where leftover is consumed
    }
    // build response message
    call THdr.set_response(msg);
    call TPload.reset_payload(msg);
    call TPload.add_offset(msg, ia_cb.offset);
    if (put.eof) {                        // ack the eof
      tn_trace_rec(my_id, 05);
      call TPload.add_eof(msg);
      if (!ia_cb.chk_good) {           // add error if check failed
        tn_trace_rec(my_id, 06);
        call TPload.add_error(msg, EINVAL);
      }
    }
    tn_trace_rec(my_id, 07);
    return TRUE;
  }

  void extract_name_params(message_t *msg) {
    int32_t         i;
    tagnet_tlv_t   *a_tlv;

    put.version.build = 0;
    put.version.minor = 0;
    put.version.major = 0;
    put.offset  = 0;
    put.size    = 0;
    for (i = 0; i < 3; i++) {
      a_tlv  = call TName.next_element(msg);
      if (a_tlv == NULL) break;
      switch (call TTLV.get_tlv_type(a_tlv)) {
        case TN_TLV_VERSION:
          call IMD.setVer(call TTLV.tlv_to_version(a_tlv), &put.version);
          break;
        case TN_TLV_OFFSET:
          put.offset = call TTLV.tlv_to_offset(a_tlv);
          break;
        case TN_TLV_SIZE:
          put.size = call TTLV.tlv_to_size(a_tlv);
          break;
        default:
          call Panic.panic(PANIC_TAGNET, TAGNET_AUTOWHERE, 0, 0, 0, 0);
          break;
      }
    }
  }

  void extract_payload_params(message_t *msg) {
    int32_t         i;
    tagnet_tlv_t   *a_tlv;

    put.eof = FALSE;
    put.dptr = NULL;
    put.dlen = 0;
    a_tlv = call TPload.first_element(msg);
    if (call THdr.is_pload_type_raw(msg)) { // msg contains raw data in payload
      put.dlen = call TPload.get_len(msg);
      put.dptr = (uint8_t *) a_tlv;
    } else {
      for (i = 0; i < 2; i++) {            // extract TLVs from payload
        if (a_tlv == NULL) break;
        switch (call TTLV.get_tlv_type(a_tlv)) {
          case TN_TLV_EOF:
            put.eof = TRUE;
            break;
          case TN_TLV_BLK:
            put.dptr = call TTLV.tlv_to_string(a_tlv, &put.dlen);
            break;
          default:
            call Panic.panic(PANIC_TAGNET, TAGNET_AUTOWHERE, 0, 0, 0, 0);
            break;
        }
        a_tlv  = call TPload.next_element(msg);
      }
    }
  }


//  event __attribute__((optimize("O0"))) bool Super.evaluate(message_t *msg) {
  event bool Super.evaluate(message_t *msg) {
    tagnet_tlv_t    *name_tlv = (tagnet_tlv_t *)tn_name_data_descriptors[my_id].name_tlv;
    tagnet_tlv_t    *help_tlv = (tagnet_tlv_t *)tn_name_data_descriptors[my_id].help_tlv;
    tagnet_tlv_t    *this_tlv = call TName.this_element(msg);
    error_t          err;
    uint8_t          ste[1];    /* just to be clear, a very small array :-) */
    image_dir_slot_t *dirp = NULL;
    int              i;

    if (call TTLV.eq_tlv(name_tlv, this_tlv)) {     //  my name == msg name
      tn_trace_rec(my_id, 8);
      extract_name_params(msg);           // extract name parameters from the msg
      switch (call THdr.get_message_type(msg)) {    // process packet type
        case TN_GET:
          tn_trace_rec(my_id, 9);
          if (!call IMD.dir_coherent()) {  // is image manager directory stable
            tn_trace_rec(my_id, 10);
            return do_reject(msg, EBUSY);
          }
          call TPload.reset_payload(msg);
          call THdr.set_response(msg);
          call THdr.set_error(msg, TE_PKT_OK);
          if (is_version_set(&put.version))
            dirp = call IMD.dir_find_ver(&put.version);
          if (dirp) {                             // get image info for one
            tn_trace_rec(my_id, 11);
            call TPload.add_version(msg, &dirp->ver_id);
            ste[0] = call IMD.slotStateLetter(dirp->slot_state);
            call TPload.add_string(msg, &ste, 1);
          } else {                                // get image info for all
            tn_trace_rec(my_id, 12);
            for (i = 0; i < IMAGE_DIR_SLOTS; i++) {
              dirp = call IMD.dir_get_dir(i);
              if (!dirp)
                break;
              call TPload.add_version(msg, &dirp->ver_id);
              ste[0] = call IMD.slotStateLetter(dirp->slot_state);
              call TPload.add_string(msg, &ste[0], 1);
            }
          }
          tn_trace_rec(my_id, 13);
          return TRUE;

        case TN_DELETE:
          tn_trace_rec(my_id, 14);
          if (!call IMD.dir_coherent()) {  // is image manager directory stable
            tn_trace_rec(my_id, 15);
            return do_reject(msg, EBUSY);
          }
          if (!is_version_set(&put.version)) {       // must have version in name
            tn_trace_rec(my_id,16);
            return do_reject(msg, EINVAL);
          }
          call TPload.reset_payload(msg);
          call THdr.set_response(msg);
          call THdr.set_error(msg, TE_PKT_OK);
          dirp = call IMD.dir_find_ver(&put.version); // get image info for specific version
          if (dirp) {
            call TPload.add_version(msg, &dirp->ver_id);
            ste[0] = call IMD.slotStateLetter(dirp->slot_state);
            call TPload.add_string(msg, &ste, 1);
          }
          if (call IM.delete(&put.version) == SUCCESS) { // delete this version
            tn_trace_rec(my_id, 17);
            return TRUE;
          }
          tn_trace_rec(my_id, 18);
          return do_reject(msg, FAIL);         // something wrong with req

        case TN_PUT:
          /*
           * get parameters from the name (version, offset, size)
           * get parameters from the payload (eof, data block)
           * if currently handling a load (in_progress == TRUE)
           * - reject(inval) if version in name doesn't match
           * - abort() if offset is zero, then treat as new load
           * - write msg data block to image manager
           * else (new load)
           * - ignore msg if offset != 0
           * - reject(inval) if eof found already (illogical)
           * - get new slot allocation from image manager
           * - reject(enomem) if alloc fails
           * - in_progress = TRUE
           * - write msg data block to image manager
           */
          tn_trace_rec(my_id, 19);
          // extract payload parameters from the msg
          extract_payload_params(msg);
          if (!is_version_set(&put.version)) { // must have version in name
            tn_trace_rec(my_id,20);
            return do_reject(msg, EINVAL);
          }

          /*
           * handle load is in progress
           */
          if (ia_cb.in_progress) {
            if (!call IMD.verEqual(&put.version, &ia_cb.version)) {
              tn_trace_rec(my_id, 21);
              return do_reject(msg, EINVAL);  // not the expected version
            }
            if (put.offset == 0) {            // start the file load over
              tn_trace_rec(my_id, 22);
              call IM.alloc_abort();
              ia_cb.in_progress = FALSE;
              // -> fall thru to new load handling below
            }
            else if (ia_cb.offset == put.offset) { // next expected put
              tn_trace_rec(my_id, 23);
              return do_write(msg);
            } else {
              tn_trace_rec(my_id, 24);
              return do_reject(msg, EINVAL);  // reject invalid offset
            }
          }
          /*
           * handle new image load request (or restart from above)
           */
          ia_cb.in_progress = FALSE;
          if (put.offset != 0) {         // ignore if not start of file
            tn_trace_rec(my_id, 25);
            break;
          }
          // allocate new image and write first data
          if ((err = call IM.alloc(&put.version)) != 0) {
            tn_trace_rec(my_id, 26);
            return do_reject(msg, err);  // failed allocate
          }
          // initialize variables used to control image load
          ia_cb.in_progress = TRUE;
          ia_cb.info_good   = FALSE;
          ia_cb.chk_good    = FALSE;
          ia_cb.eof         = FALSE;
          ia_cb.offset      = 0;
          call IMD.setVer(&put.version, &ia_cb.version);
          return do_write(msg);

        case TN_HEAD:
          call THdr.set_response(msg);
          call THdr.set_error(msg, TE_PKT_OK);
          call TPload.reset_payload(msg);
          call TPload.add_offset(msg, ia_cb.offset);
          call TPload.add_tlv(msg, help_tlv);
          tn_trace_rec(my_id, 27);
          return TRUE;

        default:
          break;
      }
    }
    call THdr.set_response(msg);
    call THdr.set_error(msg, TE_PKT_NO_MATCH);
    tn_trace_rec(my_id, 28);
    return FALSE;
  }

  event   void    IM.delete_complete() { }

  event   void    IM.dir_eject_active_complete() { }

  event   void    IM.dir_set_active_complete() { }

  event   void    IM.dir_set_backup_complete() { }

  event   void    IM.finish_complete() {
    ia_cb.in_progress = FALSE;
  }

  event   void    IM.write_continue() {
    uint32_t         dleft;

    dleft = call IM.write(&ia_buf[ia_cb.s_buf], ia_cb.e_buf - ia_cb.s_buf);
    if (dleft)
      ia_cb.s_buf = ia_cb.e_buf - dleft;
    else if (ia_cb.eof)
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

  async event void Panic.hook(){ }
}
