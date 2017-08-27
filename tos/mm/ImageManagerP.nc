/*
 * Copyright (c) 2017 Miles Maltbie, Eric B. Decker
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
 */

#include <panic.h>
#include <platform_panic.h>
#include <sd.h>
#include <image_info.h>
#include <image_mgr.h>

#ifndef PANIC_IM
enum {
  __pcode_im = unique(UQ_PANIC_SUBSYS)
};

#define PANIC_IM __pcode_im
#endif

/*
 * Primary data structures:
 *
 * directory cache, in memory copy of the image directory on the SD.
 *
 * image_manager_working_buffer (IMWB).  An SD sized (514) buffer
 * for interacting with the SD.  Used to collect (marshal) incoming
 * data for writing to the SD.
 *
 * cur_slot_blk (csb): The block in the allocated slot that we are working
 * with.
 *
 * *** State Machine Description
 *
 * IDLE         no active activity.  Free for next operation.
 *              IMWB and CSB are meaningless.
 *
 * ALLOC
 */

typedef enum {
  IMS_IDLE = 0,
  IMS_READ_DIR,
  IMS_ALLOC,
  IMS_ALLOC_WRITE_SD,
  IMS_FLUSH,
  IMS_FINISH_LAST,
  IMS_FINISH_DIR,
  IMS_DELETE_DIR,
  IMS_DSA_DIR,          /* dir_set_active, writing directory state */
} im_state_t;


module ImageManagerP {
  provides {
    interface ImageManager;
    interface FileSystem as FS;
    interface Boot as IMBooted;         /* outBoot */
  }
  uses {
    interface Boot;                     /* inBoot */
    interface SDRead;
    interface SDWrite;
    interface Resource as SDResource;   /* SD we are managing */
    interface Panic;
  }
}
implementation {

  im_state_t  im_state;                 /* current manager state */

  /*
   * control cells used when filling a slot
   */
  uint32_t    filling_slot_blk;        /* where on the sd we are writing */
  uint32_t    filling_slot_blk_limit;  /* upper limit of current slot */
  image_dir_entry_t filling_slot_p;    /* directory slot being filled */

  uint32_t    dir_blk;                  /* where the directory lives */
  image_dir_t im_dir;                   /* directory cache */

  uint32_t    im_lower, im_upper;       /* limits of the image space */

  uint8_t     im_wrk_buf[SD_BUF_SIZE];  /* working buffer. */
  uint8_t    *im_buf_ptr;               /* pntr into above buffer */
  uint16_t    im_available;             /* remaining bytes in above */


  void im_warn(uint8_t where, parg_t p0, parg_t p1) {
    call Panic.warn(PANIC_IM, where, p0, p1, 0, 0);
  }

  void im_panic(uint8_t where, parg_t p0, parg_t p1) {
    call Panic.panic(PANIC_IM, where, p0, p1, 0, 0);
  }


  error_t allocate_slot() {
    image_dir_entry_t * slot_p;
    uint16_t x;

    slot_p = NULL;
    for (x=0; x < IMAGE_DIR_SLOTS; x++) {
      if (im_dir_cache.dir.slots[x].slot_state == SLOT_EMPTY){
        slot_p = IM_SLOT_SEC(x);
        break;
      }
    }

    if (slot_p) {
      slot_p->slot_state = SLOT_FILLING;
      slot_p->ver_id = ver_id;
      slot_p->next_write_sector = 0;
      filling_slot_p = slot_p;
      return SUCCESS;
    }
    return ENOMEM;
  }


  bool cmp_ver_id(image_ver_t *ver0, image_ver_t *ver1) {
    if (ver0.major != ver1.major) return FALSE;
    if (ver0.minor != ver1.minor) return FALSE;
    if (ver0.build != ver1.build) return FALSE;
    return TRUE;
  }


  error_t dealloc_slot(ver_id) {
    image_dir_entry_t * slot_p;
    slot_p = call ImageManger.dir_find_ver(ver_id);
    if ((!slot_p) || (slot_p->slot_state != SLOT_FILLING)) {
      im_panic(1, im_state, 0);
      return (FAIL);
    }
    slot_p->slot_state = SLOT_EMPTY;
    slot_p->ver_id = 0;
    slot_p->next_write_sector = 0;
    return (SUCCESS);
  }

  image_dir_entry_t dir_find_ver(image_ver_t ver_id) {
    image_dir_entry_t * slot_p = NULL;

    for (x=0; x < IMAGE_DIR_SLOTS; x++) {
      if (cmp_ver_id(&im_dir_cache.dir.slots[x].ver_id, &ver_id)) {
        slot_p = IM_SLOT_SEC(x);
        break;
      }
    }
    return slot_p;
  }


  bool verify_IM_dir();

  void write_dir_cache() {
    if (!verify_IM_dir()) {
      im_panic(2, err, 0);
      return;
    }
    uint8_t * cache_p;
    cache_p = (uint8_t *)&im_dir_cache.dir;
    for (x = 0; x < size_of(im_dir_cache.dir); x++) {
      im_wrk_buf[x] = cache_p[x];
    }

    if (err = call SDwrite.write(IM_DIR_SEC, im_wrk_buf)) {
      im_panic(3, err, 0);
      return;
    }
  }


  void write_slot_buffer () {
    err = call SDwrite.write(cur_slot_blk, im_wrk_buf);
    if (err)
      im_panic(4, err, 0);
  }


  event void Boot.booted() {
    error_t err;

    im_lower = call FS.area_start(FS_AREA_IMAGE);
    im_upper = call FS.area_end(FS_AREA_IMAGE);
    dir_blk  = im_lower;
    if (!dir_blk) {
      im_panic(1, err, 0);
    }
    im_state = IMS_READ_DIR;
    if ((err = call SDResource.request()))
      im_panic(2, err, 0);
    return;
  }


  /*
   * Alloc: Allocate an empty slot for an incoming image
   *
   * input : ver_id     name of the image
   * output: none
   *
   * return: error_t    SUCCESS,  all good.
   *                    EBUSY,    wrong state for doing alloc
   *                    ENOMEM,   no slots available
   *                    EALREADY, image is already in the directory
   *
   * on SUCCESS, the ImageMgr will be ready to accept a new data
   * stream that is the image.  This image will be written to the
   * allocated slot.
   *
   * Only one valid image with the name ver_id is allowed.
   */

  command error_t ImageManager.alloc(image_ver_t ver_id) {
    error_t rtn;

    if (im_state != IMS_IDLE) {
        im_panic(7, im_state, 0);
        return FAIL;
    }
    if (!verify_IM_dir()) {
      im_panic(8, im_state, 0);
      return FAIL;
    }

    im_bytes_remaining = SD_BLOCKSIZE;
    im_buf_ptr = &im_wrk_buf[0];
    rtn = allocate_slot();
    if (rtn == SUCCESS)
      im_state = IMS_FILL_WAITING;
    return rtn;
  }


  /*
   * Alloc_abort: abort a current Alloc.
   *
   * input:  ver_id     version we think was allocated
   * output: none
   * return: error_t    SUCCESS,  all good.  slot marked empty
   *                    FAIL,     no alloc in progress (panic)
   */

  command error_t ImageManager.alloc_abort(image_ver_t ver_id) {
  }

  /*
   * Write: write a buffer of data to the allocated slot
   *
   * input:  buff ptr   pointer to data being written
   *         len        how much data needs to be written.
   * output: err        SUCCESS, no issues
   *                    ESIZE, write exceeds limits of slot
   *                    EINVAL, wrong state
   *
   * return: remainder  how many bytes still need to be written
   *
   * ImageManager will move the bytes from buff into the working buffer
   * (wbuff).  It will stop when wbuff is full.  It will return the number
   * of bytes that haven't been copied.  If it returns 0, the incoming
   * buffer has been completely consumed.  This indicates that the incoming
   * buffer can be released by the caller and used for other activities.
   *
   * When there is a remainder, the remaining bytes in the incoming buffer
   * still need be written.  But this can not happen until after wbuff has
   * been written to disk.  The caller must wait for the write_complete
   * signal.  It can then resend the remaining bytes using another call to
   * ImageManager.write(...).
   */

  command uint16_t ImageManager.write(uint8_t *buf, uint16_t len, error_t err) { }

  command error_t ImageManager.finish(image_ver_t ver_id) { }

  command error_t ImageManager.delete(image_ver_t ver_id) { }

  command error_t ImageManager.dir_set_active(image_ver_t ver_id) { }

  command error_t ImageManager.check_fit(uint32_t len) { }

  command image_dir_entry_t *ImageManager.dir_get_active() { }
  command image_dir_entry_t *ImageManager.dir_get_dir(uint8_t idx) { }
  command image_dir_entry_t *ImageManager.dir_find_ver(image_ver_t ver_id) { }


  event void SDResource.granted() {
    error_t err;

    switch(im_state) {
      default:
        im_panic(3, im_state, 0);
        return;

      case IMS_READ_DIR:
        if ((err = call SDread.read(dir_blk, im_wrk_buf))) {
          im_panic(4, err, 0);
          return;
        }
        return;

      case IMS_ALLOC_WRITE_SD:
      case IMS_FINISH_LAST:
      case IMS_FINISH_DIR:
      case IMS_DELETE_DIR:
      case IMS_DSA_DIR:
        return;
    }
  }


  event void SDread.readDone(uint32_t blk_id, uint8_t *read_buf, error_t err) {
    switch(im_state) {
      default:
        im_panic(24, im_state, 0);
        return(FAIL);

      case IMS_FILL_WAITING:
        slot_p->slot_state = SLOT_VALID;
        call SDResource.request();

        if (im_bytes_remaining == SD_BLOCKSIZE) { /* If the buffer is empty */
          im_state = IMS_FILL_SYNC_REQ_SD;
        } else {
          im_state = IMS_FILL_LAST_REQ_SD;
        }
        return(SUCCESS);
    }


    /*
     * Write: write a buffer of data to the allocated slot
     *
     * input:  buff ptr   pointer to data being written
     *         len        how much data needs to be written.
     * output: err        SUCCESS, no issues
     *                    ESIZE, write exceeds limits of slot
     *                    EINVAL, wrong state
     *
     * return: remainder  how many bytes still need to be written
     *
     * ImageManager will move the bytes from buff into the working buffer
     * (wbuff).  It will stop when wbuff is full.  It will return the number
     * of bytes that haven't been copied.  If it returns 0, the incoming
     * buffer has been completely consumed.  This indicates that the incoming
     * buffer can be released by the caller and used for other activities.
     *
     * When there is a remainder, the remaining bytes in the incoming buffer
     * still need be written.  But this can not happen until after wbuff has
     * been written to disk.  The caller must wait for the write_complete
     * signal.  It can then resend the remaining bytes using another call to
     * ImageManager.write(...).
     */
    command uint16_t ImageManager.write(uint8_t *buf, uint16_t len, error_t err) {
      uint16_t copy_len;
      uint16_t bytes_left;

      switch(im_state) {
        default:
          im_panic(25, im_state, 0);
          return(0);

        case IMS_FILL_WAITING:
          if ((im_buf_ptr < &im_wrk_buf[0])
              || (im_buf_ptr > &im_wrk_buf[SD_BUF_SIZE)]) {
            im_panic(26, im_state, 0);
            return(0);
          }
          if (len <= im_bytes_remaining) {
            copy_len = len;
            im_bytes_remaining -= len;
            bytes_left = 0;
          } else {
            copy_len = im_bytes_remaining;
            bytes_left = len - copy_len;
            im_bytes_remaining = 0;
          }

          for (x = 0; x < copy_len; x++) {
            *im_buf_ptr++ = buf[x];
          }
          if (bytes_left) {
            im_state = IMS_FILL_REQ_SD;
            call SDResource.request();
          }
          return(bytes_left);
      }
    }


    event void SDResource.granted() {
      error_t err;

      switch(im_state) {
        default:
          im_panic(27, im_state, 0);
          return;

        case IMS_INIT_REQ_SD:
          im_state = IMS_INIT_READ_DIR;
          err = call SDread.read(IM_DIR_SEC, im_wrk_buf);
          if (err) {
            im_panic(28, err, 0);
            return;
          }
          return;

        case IMS_FILL_REQ_SD:
          im_state = IMS_FILL_WRITING;
          write_slot_buffer();
          return;

        case IMS_FILL_LAST_REQ_SD:
          im_state = IMS_FILL_LAST_WRITE;
          write_slot_buffer();
          return;

        case IMS_FILL_SYNC_REQ_SD:
          im_state = IMS_FILL_SYNC_WRITE;
          write_dir_cache();
          return;

        case IMS_DELETE_SYNC_REQ_SD:
          im_state = IMS_DELETE_SYNC_WRITE;
          write_dir_cache();
          return;
      }
    }

    event void SDread.readDone(uint32_t blk_id, uint8_t *read_buf, error_t err){
      switch(im_state) {
        default:
          im_panic(29, im_state, 0);
          return;

        case IMS_INIT_READ_DIR:
          if (err) {
            im_panic(30, err, 0);
            return;
          }

          /* working buffer has the directory structure in it now.
           * copy over to working directory cache.
           */
          uint8_t * cache_p = (uint8_t *)&im_dir_cache.dir;
          for (x = 0; x < size_of(im_dir_cache.dir); x++) {
            cache_p[x] = im_wrk_buf[x];
          }

          /* verify sig and checksum */
          if (!verify_IM_dir()) {
            im_panic(31, err, 0);
            return;
          }
          im_state = IDLE;
          call SDResource.release();
          signal IMBooted.booted();
          return;
      }
    }

      case IMS_READ_DIR:
        if (err) {
          im_panic(6, err, 0);
          return;
        }

        /* working buffer has the directory structure in it now.
         * copy over to working directory cache.
         */

        /* verify sig */
        /* any other verification */


        /* copy directory into dir cache */

        im_state = IDLE;
        call SDResource.release();
        signal IMBooted.booted();
        return;
    }
  }
}
