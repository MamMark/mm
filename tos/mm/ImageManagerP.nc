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
 * im_filling_slot_blk (fsb): The block in the allocated slot that we are working
 * with.
 *
 * *** State Machine Description
 *
 * IDLE                no active activity.  Free for next operation.
 *                     IMWB and CSB are meaningless.
 * FILL_WAITING        filling buffer.  IMWB and CSB active.
 * FILL_REQ_SD         req SD for IMWB flush.
 * FILL_WRITING        writing buffer (IMWB) to SD.
 * FILL_LAST_REQ_SD    req SD for last buffer write.
 * FILL_LAST_WRITE     finishing write of last buffer (partial).
 * FILL_SYNC_REQ_SD    req SD to write directory to finish new image.
 * FILL_SYNC_WRITE     write directory to update image finish.
 * DELETE_SYNC_REQ_SD  req SD for directory flush for delete.
 * DELETE_SYNC_WRITE   Flush directory cache for new empty entry
 * DELETE_COMPLETE     ????
 * DSA_DIR
 */

typedef enum {
  IMS_IDLE                      = 0,
  IMS_INIT_REQ_SD,
  IMS_INIT_READ_DIR,
  IMS_FILL_WAITING,
  IMS_FILL_REQ_SD,
  IMS_FILL_WRITING,
  IMS_FILL_LAST_REQ_SD,
  IMS_FILL_LAST_WRITE,
  IMS_FILL_SYNC_REQ_SD,
  IMS_FILL_SYNC_WRITE,
  IMS_DELETE_SYNC_REQ_SD,
  IMS_DELETE_SYNC_WRITE,
  IMS_DELETE_COMPLETE,
  IMS_DSA_DIR,                          /* dir_set_active, writing directory state */
} im_state_t;


module ImageManagerP {
  provides {
    interface ImageManager;
    interface FileSystem as FS;
    interface Boot as IMBooted;         /* outBoot */
  }
  uses {
    interface Boot;                     /* inBoot */
    interface SDread;
    interface SDwrite;
    interface Resource as SDResource;   /* SD we are managing */
    interface Panic;
  }
}
implementation {

  im_state_t  im_state;                 /* current manager state */

  /*
   * Image directory cache is a copy of the directory from the Image Area
   * on the SD.
   *
   * It holds changes made to the directory prior to being committed.
   */
  image_dir_cache_t im_dir_cache;

  /*
   * control cells used when filling a slot
   */
  uint32_t    filling_slot_blk;         /* where on the sd we are writing */
  uint32_t    filling_slot_blk_limit;   /* upper limit of current slot */

  uint8_t     im_wrk_buf[SD_BUF_SIZE];  /* working buffer. */
  uint8_t    *im_buf_ptr;               /* pntr into above buffer */
  uint16_t    im_bytes_remaining;       /* remaining bytes in above */
  image_dir_entry_t                     /* directory slot being filled */
             *im_filling_slot_p;

  uint8_t   im_wrk_buf[SD_BUF_SIZE];    /* working buffer. */
  uint8_t  *im_buf_ptr;                 /* pntr into above buffer */
  uint16_t  im_bytes_remaining;         /* remaining bytes in above */
  uint16_t  im_filling_slot_id;         /* index of the slot being filled */
  image_dir_entry_t *im_filling_slot_p;

  void im_warn(uint8_t where, parg_t p0, parg_t p1) {
    call Panic.warn(PANIC_IM, where, p0, p1, 0, 0);
  }

  void im_panic(uint8_t where, parg_t p0, parg_t p1) {
    call Panic.panic(PANIC_IM, where, p0, p1, 0, 0);
  }


  error_t allocate_slot (image_ver_t ver_id, uint16_t *slot_id) {
    image_dir_entry_t * slot_p;
    uint16_t x;

    *slot_id = -1;
    slot_p = NULL;
    for (x=0; x < IMAGE_DIR_SLOTS; x++) {
      if (im_dir_cache.dir.slots[x].slot_state == SLOT_EMPTY){
        slot_p = &im_dir_cache.dir.slots[x];
        break;
      }
    }

    if (slot_p) {
      slot_p->slot_state = SLOT_FILLING;
      slot_p->ver_id = ver_id;
      *slot_id = x;
      return SUCCESS;
    }
    return ENOMEM;
  }


  bool cmp_ver_id(image_ver_t *ver0, image_ver_t *ver1) {
    if (ver0->major != ver1->major) return FALSE;
    if (ver0->minor != ver1->minor) return FALSE;
    if (ver0->build != ver1->build) return FALSE;
    return TRUE;
  }


  image_dir_entry_t *dir_find_ver(image_ver_t ver_id) {
    image_dir_entry_t * slot_p = NULL;
    int x;

    for (x = 0; x < IMAGE_DIR_SLOTS; x++) {
      if (cmp_ver_id(&im_dir_cache.dir.slots[x].ver_id, &ver_id)) {
        slot_p = &im_dir_cache.dir.slots[x];
        break;
      }
    }
    return slot_p;
  }


  error_t dealloc_slot(image_ver_t ver_id) {
    image_dir_entry_t * slot_p;

    slot_p = call IM.dir_find_ver(ver_id);
    if ((!slot_p) || (slot_p->slot_state != SLOT_FILLING)) {
      im_panic(1, im_state, slot_p->slot_state);
      return FAIL;
    }
    slot_p->slot_state = SLOT_EMPTY;
    memset(&slot_p->ver_id, 0, sizeof(slot_p->ver_id));
    return SUCCESS;
  }


  /*
   * verify that the current state of Image Manager control
   * cells are reasonable.
   *
   * If not, panic.
   */
  void verify_IM_dir() { }

  void write_dir_cache() {
    uint8_t * cache_p;
    int x;
    error_t err;

    verify_IM_dir();
    cache_p = (uint8_t *)&im_dir_cache.dir;
    for (x = 0; x < sizeof(im_dir_cache.dir); x++) {
      im_wrk_buf[x] = cache_p[x];
    }

    if ((err = call SDwrite.write(IM_DIR_SEC, im_wrk_buf))) {
      im_panic(3, err, 0);
      return;
    }
  }


  void write_slot_buffer () {
    error_t err;

    err = call SDwrite.write(im_dir_cache.next_write_blk, im_wrk_buf);
    if (err)
      im_panic(4, err, 0);
  }


  event void Boot.booted() {
    error_t err;

    im_dir_cache.start_blk = call FS.area_start(FS_LOC_IMAGE);
    im_dir_cache.end_blk   = call FS.area_end(FS_LOC_IMAGE);

    /* first block of the area is reserved for the ImagaManager
     * directory.  The macro IM_DIR_SEC also references this
     * block id.
     */
    if ( ! im_dir_cache.start_blk)
      im_panic(5, 0, 0);
    im_state = IMS_INIT_REQ_SD;
    if ((err = call SDResource.request()))
      im_panic(6, err, 0);
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

  command error_t IM.alloc(image_ver_t ver_id) {
    error_t rtn;
    uint16_t x;

    if (im_state != IMS_IDLE) {
        im_panic(7, im_state, 0);
        return FAIL;
    }
    verify_IM_dir();
    im_bytes_remaining = SD_BLOCKSIZE;
    im_buf_ptr = &im_wrk_buf[0];
    rtn = allocate_slot(ver_id, &x);
    if (!rtn) return rtn;
    im_dir_cache.next_write_blk = im_dir_cache.dir.slots[x].s0;
    im_dir_cache.limit_write_blk = IM_SLOT_LAST_SEC(x);
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

  command error_t IM.alloc_abort(image_ver_t ver_id) {
    image_dir_entry_t * slot_p;

    verify_IM_dir();
    switch(im_state) {
      default:
        im_panic(10, im_state, 0);
        return FAIL;

      case IMS_FILL_WAITING:
        dealloc_slot(ver_id);
        im_state = IMS_IDLE;
        return SUCCESS;
    }
  }


  /*
   * Check_fit: Verifies that request length will fit image slot.
   *
   * input:  len        length of image being pushed to SD
   * output: none
   * return: bool       TRUE.  image fits.
   *                    FALSE, image too big for slot
   */

  command bool IM.check_fit(uint32_t len) {
    if (len <= IMAGE_SIZE) return TRUE;
    im_panic(11, im_state, len);
    return FALSE;
  }


  /*
   * Delete: Sets the state of an image  to "empty", marking the slot  available for another image.
   *
   * input: ver_id
   * output: none
   *
   * return: error_t
   */

  command error_t IM.delete(image_ver_t ver_id) {
    image_dir_entry_t *slot_p;

    verify_IM_dir();
    switch(im_state) {
      default:
        im_panic(13, im_state, 0);
        return FAIL;

      case IMS_IDLE:
        slot_p  = call IM.dir_find_ver(ver_id);
        if (slot_p == NULL) {
          im_panic(14, im_state, 0);
          return FAIL;
        }
        im_state = IMS_DELETE_SYNC_REQ_SD;
        slot_p->slot_state = SLOT_EMPTY;
        call SDResource.request();
        return SUCCESS;
    }
  }


  /*
   *
   * dir_find_ver: Returns a pointer to the slot for given image version.
   *
   * input: ver_id
   * output: none
   *
   * return: dir_find_ver(ver_id)
   */

  command image_dir_entry_t *IM.dir_find_ver(image_ver_t ver_id) {
    verify_IM_dir();
    switch(im_state) {
      default:
        im_panic(16, im_state, 0);
        return NULL;

      case IMS_IDLE:
        return dir_find_ver(ver_id);
    }
  }


  /*
   *
   * dir_get_active: Returns a pointer to the  entry that is currently set to the active image.
   *                 Returns "null" if there is no active image set in image directory.
   *
   * input: none
   * output: none
   *
   * return: slot_p, error_t
   */

  command image_dir_entry_t *IM.dir_get_active() {
    image_dir_entry_t *slot_p;
    bool found_it;
    int x;

    verify_IM_dir();
    switch(im_state) {
      default:
        im_panic(18, im_state, 0);
        return NULL;

      case IMS_IDLE:
        slot_p = NULL;
        found_it = FALSE;

        for (x = 0; x < IMAGE_DIR_SLOTS; x++) {
          if (im_dir_cache.dir.slots[x].slot_state == SLOT_ACTIVE) {
            slot_p = &im_dir_cache.dir.slots[x];
            if (found_it) {
              im_panic(19, im_state, 0);
              return NULL;
            }
            found_it = TRUE;
          }
        }
        return slot_p;
    }
  }


  /*
   *
   * dir_get_dir: Returns a pointer to the image directory indexed by idx
   *                        This call can be used to itterate through the current contents of image directory.
   *
   * input: idx
   * output: image_dir_entry_t
   *
   * return:
   */

  command image_dir_entry_t *IM.dir_get_dir(uint8_t idx) {
    verify_IM_dir();
    switch(im_state) {
      default:
        im_panic(21, im_state, 0);
        return NULL;

      case IMS_IDLE:
        return &im_dir_cache.dir.slots[idx];
    }
  }


  /*
   * dir_set_active: Verifies that one image in directory is set as valid,
   *                 Sets the image state to Active for given ver_id.
   *
   * input: ver_id
   * output: none
   *
   * return: error_t
   */

  command error_t IM.dir_set_active(image_ver_t ver_id) {
    image_dir_entry_t *slot_p;

    verify_IM_dir();
    switch(im_state) {
      default:
        im_panic(22, im_state, 0);
        return FAIL;

      case IMS_IDLE:
        slot_p = call IM.dir_find_ver(ver_id);
        if ((!slot_p) || (slot_p->slot_state != SLOT_VALID)) {
          im_panic(23, im_state, 0);
          return FAIL;
        }
        slot_p->slot_state = SLOT_ACTIVE;
        return SUCCESS;
    }
  }


  /*
   *
   * finish: Writes any remaining bytes of data in the image working buffer to the disk. Marks image as valid.
   * Commits image data to image directory.
   *
   * input: buf, len
   * output: none
   *
   * return: error_t
   */

  command error_t IM.finish(image_ver_t ver_id) {

    verify_IM_dir();
    switch(im_state) {
      default:
        im_panic(24, im_state, 0);
        return FAIL;

      case IMS_FILL_WAITING:
        im_filling_slot_p->slot_state = SLOT_VALID;
        call SDResource.request();

        /*
         * if there are no bytes in the IMWB then immediately transition
         * to writing/syncing the dir cache to the directory.
         */
        if (im_bytes_remaining == SD_BLOCKSIZE)
             im_state = IMS_FILL_SYNC_REQ_SD;
        else im_state = IMS_FILL_LAST_REQ_SD;
        return SUCCESS;
    }
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

  command uint16_t IM.write(uint8_t *buf, uint16_t len, error_t err) {
    uint16_t copy_len;
    uint16_t bytes_left;
    int x;

    verify_IM_dir();
    switch(im_state) {
      default:
        im_panic(25, im_state, 0);
        return 0;

      case IMS_FILL_WAITING:
        if ((im_buf_ptr < &im_wrk_buf[0]) ||
            (im_buf_ptr >= &im_wrk_buf[SD_BUF_SIZE])) {
          im_panic(26, im_state, 0);
          return 0;
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
          if (im_dir_cache.next_write_blk > im_dir_cache.dir.slots[im_filling_slot_id].end_blk)
            im_panic(27, im_dir_cache.next_write_blk, im_filling_slot_id);

          im_state = IMS_FILL_REQ_SD;
          call SDResource.request();
        }
        return bytes_left;
    }
  }


  event void SDResource.granted() {
    error_t err;

    switch(im_state) {
      default:
        im_panic(28, im_state, 0);
        return;

      case IMS_INIT_REQ_SD:
        im_state = IMS_INIT_READ_DIR;
        err = call SDread.read(IM_DIR_SEC, im_wrk_buf);
        if (err) {
          im_panic(29, err, 0);
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


  event void SDread.readDone(uint32_t blk_id, uint8_t *read_buf, error_t err) {
    uint8_t *cache_p;
    int x;

    switch (im_state) {
      default:
        im_panic(30, im_state, 0);
        return;

      case IMS_INIT_READ_DIR:
        if (err) {
          im_panic(31, err, 0);
          return;
        }
        /* working buffer is zeroed out   */
        for (x = 0; x < sizeof(im_dir_cache.dir); x++) {
          if (im_wrk_buf[x] != 0) {
            break;
          }
        }

#ifdef notdef
        if (x >= sizeof(im_dir_cache.dir))
            init.dir();
#endif

        /* working buffer has the directory structure in it now.
         * copy over to working directory cache.
         */
        cache_p = (uint8_t *)&im_dir_cache.dir;
        for (x = 0; x < sizeof(im_dir_cache.dir); x++) {
          cache_p[x] = im_wrk_buf[x];
        }

        /* write im_wrk_buf to SD (if was just initialized) */

        /* verify sig and checksum */
        verify_IM_dir();

        /* copy directory into dir cache */

        im_state = IMS_IDLE;
        call SDResource.release();
        signal IMBooted.booted();
        return;

      case IMS_FILL_WAITING:
        im_filling_slot_p->slot_state = SLOT_VALID;
        call SDResource.request();

        if (im_bytes_remaining == SD_BLOCKSIZE) { /* If the buffer is empty */
          im_state = IMS_FILL_SYNC_REQ_SD;
        } else {
          im_state = IMS_FILL_LAST_REQ_SD;
        }
        return;
    }
  }


  event void SDwrite.writeDone(uint32_t blk, uint8_t *buf, error_t error) {
    switch(im_state) {
      default:
        im_panic(33, im_state, 0);
        return;

      case IMS_FILL_WRITING:
        im_state = IMS_FILL_WAITING;
        im_dir_cache.next_write_blk++;

        call SDResource.release();
        signal IM.write_continue();
        return;

      case IMS_FILL_LAST_WRITE:
        im_state = IMS_FILL_SYNC_WRITE;
        write_dir_cache();
        return;

      case IMS_FILL_SYNC_WRITE:
        im_state = IMS_IDLE;
        call SDResource.release();
        signal IM.finish_complete();
        return;

      case IMS_DELETE_SYNC_WRITE:
        im_state = IMS_IDLE;
        call SDResource.release();
        signal IM.delete_complete();
        return;
    }
  }

  async event void Panic.hook() { }
}
