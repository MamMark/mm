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
 *
 * 0) review statemachine vs. implementation
 * 4) dir_set_active dir sync
 * 5) dir_set_backup
 * 6) dir_eject_active
 *
 * Unit testing.
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
 * Image Manager Control Block:  The imcb collects all reasonable state
 *   information about what the ImageManager is currently doing.
 *
 *   region_start_blk:  where the ImageManager's region starts and end.  Do
 *   region_end_blk     not go outside these bounds.
 *
 *   dir                directory cache, ram copy of IM dir
 *   filling_blk:       When writing a slot, filling_blk is the next block that
 *   filling_limit_blk: will be written.  limit_blk is the limit of the slot
 *                      do not exceed.
 *
 *   filling_slot_p:    pointer to the current slot we are filling.
 *
 *   buf_ptr:           When filling, buf_ptr keeps track of where in the
 *                      IMWB we currently are working.
 *   bytes_remaining:   how much space is remaining before filling the IMWB.
 *   im_state:          current state of the ImageManager
 *
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
 * DSA_DIR
 */

typedef enum {
  IMS_IDLE                      = 0,
  IMS_INIT_REQ_SD,
  IMS_INIT_READ_DIR,
  IMS_INIT_SYNC_WRITE,

  IMS_FILL_WAITING,             /* filling states through FILL_SYNC_WRITE */
  IMS_FILL_REQ_SD,              /* these are grouped together as the      */
  IMS_FILL_WRITING,             /* FILLING meta state                     */

  IMS_FILL_LAST_REQ_SD,
  IMS_FILL_LAST_WRITE,
  IMS_FILL_SYNC_REQ_SD,
  IMS_FILL_SYNC_WRITE,          /* end of filling states */
  IMS_DELETE_SYNC_REQ_SD,
  IMS_DELETE_SYNC_WRITE,
  IMS_DSA_SYNC_REQ_SD,          /* dir_set_active */
  IMS_DSA_SYNC_WRITE,
  IMS_DSB_SYNC_REQ_SD,          /* dir_set_backup */
  IMS_DSB_SYNC_WRITE,
  IMS_EJECT_SYNC_REQ_SD,        /* dir_eject_active */
  IMS_EJECT_SYNC_WRITE,
  IMS_MAX
} im_state_t;


/*
 * filling_slot_p and buf_ptr will be NULL when not in a FILLING meta state
 * will be valid while in a FILLING meta state
 */
typedef struct {
  uint32_t region_start_blk;            /* start/end region limits from  */
  uint32_t region_end_blk;              /* file system                   */

  image_dir_t dir;                      /* directory cache */

  uint32_t filling_blk;                 /* filling, next block to write  */
  uint32_t filling_limit_blk;           /* filling, limit of the slot    */

  image_dir_slot_t *filling_slot_p;     /* filling, pnt to slot being filled */

  uint8_t  *buf_ptr;                    /* filling, pntr into IMWB       */
  uint16_t  bytes_remaining;            /* filling, bytes left in IMWB   */

  im_state_t im_state;                  /* current state */
} imcb_t;                               /* ImageManager Control Block (imcb) */


module ImageManagerP {
  provides {
    interface Boot         as Booted;   /* outBoot */
    interface ImageManager as IM;
  }
  uses {
    interface Boot;                     /* inBoot */
    interface FileSystem   as FS;
    interface Resource as SDResource;   /* SD we are managing */
    interface Checksum;
    interface SDread;
    interface SDwrite;
    interface Panic;
  }
}
implementation {
  /*
   * IMWB: ImageManager Working Buffer, this buffer is used
   * to accumulate incoming bytes when writing an image to a slot.
   *
   * The IMWB is aligned to allow quad word aligned access, ie chk_zero.
   */
  uint8_t     im_wrk_buf[SD_BUF_SIZE] __attribute__((aligned(4)));

  /*
   * control cells, imcb, ImageManager Control Block
   */
  imcb_t imcb;


  void im_warn(uint8_t where, parg_t p0, parg_t p1) {
    call Panic.warn(PANIC_IM, where, p0, p1, 0, 0);
  }

  void im_panic(uint8_t where, parg_t p0, parg_t p1) {
    call Panic.panic(PANIC_IM, where, p0, p1, 0, 0);
  }


  /*
   * check for a zero buffer.
   *
   * assumes quad-byte aligned.
   *
   * if tail is not quad even, then we have to adjust the
   * last reference.    19-18-17-16, len 3, we want 0x00FFFFFF
   */

  bool chk_zero(uint8_t *buf, uint32_t len) {
    uint32_t *p;

    p = (void *) buf;
    while (1) {
      if (*p++) return FALSE;
      len -= 4;
      if (len < 3)
        break;
    }
    if (!len) return TRUE;
    if (*p & (0xffffffff >> ((4 - len) * 8)))
      return FALSE;
    return TRUE;
  }


  bool cmp_ver_id(image_ver_t *ver0, image_ver_t *ver1) {
    if (ver0->major != ver1->major) return FALSE;
    if (ver0->minor != ver1->minor) return FALSE;
    if (ver0->build != ver1->build) return FALSE;
    return TRUE;
  }


  /*
   * verify that the current state of Image Manager control
   * cells are reasonable.
   *
   * If not, panic.
   *
   * buf_ptr NULL or within bounds
   */
  void verify_IM() {
    uint32_t checksum;
    image_dir_t *dir;
    image_dir_slot_t *slot_p;
    parg_t panic_val;
    uint32_t slot_start, slot_end;
    int i;
    int active_count;
    int backup_count;
    bool fsp_found;
    bool bail;

    bail = FALSE;
    panic_val = 0;
    slot_start = slot_end = 0;          /* shut compiler up */

    do {

      /*
       * validate control structures
       *
       * 1) check IM state
       * 2) check region bounds
       * 3) directory scan
       *    . signature
       *    . checksum
       *    . entry state
       *    . start_sec valid for slot and within bounds
       *    . find filling_slot_p if any
       *    . count active and backup if any
       * 4) check for correct number of active and backups
       * 5) If Filling
       *    . check filling_slot_p reasonable (see dir scan)
       *    . buf_ptr, bytes_remaining
       *    . filling_blk, filling_limit_blk point into valid slot
       * 6) If not filling
       *    fsp_found (should be FALSE)
       *    buf_ptr and filling_slot_p should be NULL
       */

      /* Check IM state within bounds */
      if (imcb.im_state < IMS_IDLE ||
          imcb.im_state >= IMS_MAX) {
        panic_val = 1;
        break;
      }

      /* region start / end block check */
      if (imcb.region_start_blk != call FS.area_start(FS_LOC_IMAGE) ||
          imcb.region_end_blk != call FS.area_end(FS_LOC_IMAGE)) {
        panic_val = 2;
        break;
      }

      /*
       * do directory checks first.
       */
      dir = &imcb.dir;

      /* Check the directory signatures */
      if (dir->dir_sig != IMAGE_DIR_SIG ||
          dir->dir_sig_a != IMAGE_DIR_SIG) {
        panic_val = 3;
        break;
      }

      /* Check the checksum, should return 0 if dir is valid */
      checksum = call Checksum.sum32_aligned((void *) dir, sizeof(*dir));
      if (checksum) {
        panic_val = 4;
        break;
      }

      fsp_found = FALSE;
      active_count = 0;
      backup_count = 0;
      for (i = 0; i < IMAGE_DIR_SLOTS; i++) {
        /*
         * Check slot state
         * Check FSP Match
         * Check start sec
         */
        slot_p = &imcb.dir.slots[i];
        if (slot_p->slot_state < SLOT_EMPTY ||
            slot_p->slot_state >= SLOT_MAX) {
          panic_val = 5;
          bail = TRUE;
          break;
        }
        if (slot_p->slot_state == SLOT_ACTIVE)
          active_count++;
        if (slot_p->slot_state == SLOT_BACKUP)
          backup_count++;

        /* check for filling_slot_p presence */
        if (slot_p == imcb.filling_slot_p) {
          fsp_found = TRUE;
          if (slot_p->slot_state != SLOT_FILLING) {
            panic_val = 6;
            bail = TRUE;
            break;
          }
          slot_start = slot_p->start_sec;
          slot_end   = slot_p->start_sec + IMAGE_SIZE - 1;
        }
        if (slot_p->start_sec != (imcb.region_start_blk + ((IMAGE_SIZE_SECTORS * i) + 1))) {
          panic_val = 7;
          bail = TRUE;
          break;
        }
        if (slot_p->start_sec < imcb.region_start_blk ||
            slot_p->start_sec > imcb.region_end_blk) {
          panic_val = 8;
          bail = TRUE;
          break;
        }
      }
      if (bail)
        break;

      /*
       * directory scan complete
       *
       * how many active/backups found
       */
      if (active_count > 1 || backup_count > 1) {
          panic_val = 9;
          break;
      }

      if (imcb.im_state >= IMS_FILL_WAITING &&
          imcb.im_state <= IMS_FILL_SYNC_WRITE) {
        /*
         * In a FILLING state, do FILLING checks
         */
        if (!fsp_found) {
          panic_val = 10;
          break;
        }

        /*
         * Check filling_blk, filling_limit_blk
         * the slot block is defined by filling_slot_p->start_sec
         * and filling_limit_blk is calculated from start_sec.
         *
         * slot_start and end are set above and are the limits we
         * check against.
         */

        if (imcb.filling_blk < slot_start ||
            imcb.filling_blk > slot_end   ||
            imcb.filling_limit_blk < slot_start ||
            imcb.filling_limit_blk > slot_end ||
            imcb.filling_blk > imcb.filling_limit_blk) {
          panic_val = 11;
          break;
        }

        /*
         * filling so buf_ptr must be either within bounds of the
         * IMWB or just beyond (im_wrk_buf[SD_BUF_SIZE])
         */
        if (imcb.buf_ptr < im_wrk_buf ||
            imcb.buf_ptr > &im_wrk_buf[SD_BUF_SIZE]) {
          panic_val = 12;
          break;
        }

      } else {
        /*
         * not filling, verify reasonableness
         *
         * fsp_found should be FALSE
         * buf_ptr and filling_slot_p should both be NULL
         */
        if (fsp_found || imcb.buf_ptr || imcb.filling_slot_p) {
          panic_val = 13;
          break;
        }
      }
    } while (0);
    if (panic_val)
      im_panic(2, panic_val, imcb.im_state);
  }


  void write_dir_cache() {
    error_t err;

    verify_IM();
    if ((err = call SDwrite.write(imcb.region_start_blk, (void *) &imcb.dir))) {
      im_panic(3, err, 0);
      return;
    }
  }


  void write_slot_blk() {
    error_t err;

    if (imcb.filling_blk > imcb.filling_limit_blk)
      im_panic(3, imcb.filling_blk, imcb.filling_limit_blk);
    err = call SDwrite.write(imcb.filling_blk, im_wrk_buf);
    if (err)
      im_panic(4, err, 0);
  }


  /*
   * get_active_backup: find the active and/or backup dir slot if any
   *
   * input:  a, b       ptrs (pass by ref) to dir_slot ptrs
   *                    NULL if we aren't looking for said slot
   * output: *a, *b     updated to point at active/backup slots respectively.
   * return: none
   *
   * assumes that a reasonable call of verify_IM() has occured prior to calling
   * get_active_backup.
   */
  void get_active_backup(image_dir_slot_t **a, image_dir_slot_t **b) __attribute__((noinline)) {
    image_dir_slot_t *sp;
    int i;

    if (a) *a = NULL;
    if (b) *b = NULL;
    for (i = 0; i < IMAGE_DIR_SLOTS; i++) {
      sp = &imcb.dir.slots[i];
      if (a && sp->slot_state == SLOT_ACTIVE)
        *a = sp;
      if (b && sp->slot_state == SLOT_BACKUP)
        *b = sp;
    }
  }


  event void Boot.booted() {
    error_t err;

    imcb.region_start_blk = call FS.area_start(FS_LOC_IMAGE);
    imcb.region_end_blk   = call FS.area_end(FS_LOC_IMAGE);

    /*
     * first block of the area is reserved for the ImageManager
     * directory.
     */
    if ( ! imcb.region_start_blk)
      im_panic(5, 0, 0);
    imcb.im_state = IMS_INIT_REQ_SD;
    if ((err = call SDResource.request()))
      im_panic(6, err, 0);
  }


  /*
   * Alloc: Allocate an empty slot for an incoming image
   *
   * input : ver_id     name of the image
   * return: error_t    SUCCESS,  all good.
   *                    ENOMEM,   no slots available
   *                    EALREADY, image is already in the directory
   *
   * on SUCCESS, the ImageMgr will be ready to accept the data
   * stream that is the image.
   *
   * Only one valid image with the name ver_id is allowed.
   */
  command error_t IM.alloc(image_ver_t ver_id) {
    image_dir_t *dir;
    image_dir_slot_t *sp, *ep;          /* slot ptr, empty ptr */
    imcb_t *imcp;
    int i;

    imcp = &imcb;
    if (imcp->im_state != IMS_IDLE) {
        im_panic(7, imcp->im_state, 0);
        return FAIL;
    }

    ep = NULL;
    dir = &imcb.dir;
    verify_IM();

    /*
     * scan the directory looking for the ver_id (only if VALID or above).
     * Also find the first empty slot.
     */
    for (i = 0; i < IMAGE_DIR_SLOTS; i++) {
      sp = &dir->slots[i];
      if ((sp->slot_state >= SLOT_VALID) &&
          cmp_ver_id(&(sp->ver_id), &ver_id))
        return EALREADY;
      if (!ep && sp->slot_state == SLOT_EMPTY)
        ep = sp;
    }
    if (!ep)
      return ENOMEM;
    ep->slot_state = SLOT_FILLING;
    ep->ver_id = ver_id;
    dir->chksum = 0 - call Checksum.sum32_aligned((void *) dir, sizeof(*dir));

    imcp->filling_blk = ep->start_sec;
    imcp->filling_limit_blk = ep->start_sec + IMAGE_SIZE_SECTORS - 1;
    imcp->filling_slot_p = ep;

    imcp->buf_ptr = &im_wrk_buf[0];
    imcp->bytes_remaining = SD_BLOCKSIZE;
    imcp->im_state = IMS_FILL_WAITING;
    return SUCCESS;
  }


  /*
   * Alloc_abort: abort a current Alloc.
   *
   * input:  none
   * output: none
   * return: error_t    SUCCESS,  all good.  slot marked empty
   *                    FAIL,     no alloc in progress (panic)
   *
   * alloc_abort can only be called in IMS_FILL_WAITING.  This
   * means if IM.write ever returns non-zero, one MUST wait
   * for a IM.write_complete before calling alloc_abort.
   */
  command error_t IM.alloc_abort() {
    image_dir_t *dir;

    if (imcb.im_state != IMS_FILL_WAITING) {
      im_panic(10, imcb.im_state, 0);
      return FAIL;
    }
    verify_IM();
    imcb.filling_slot_p->slot_state = SLOT_EMPTY;
    imcb.buf_ptr = NULL;
    imcb.filling_slot_p = NULL;
    imcb.im_state = IMS_IDLE;
    dir = &imcb.dir;
    dir->chksum = 0 - call Checksum.sum32_aligned((void *) dir, sizeof(*dir));
    return SUCCESS;
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
    im_panic(11, imcb.im_state, len);
    return FALSE;
  }


  /*
   * Delete: Sets the state of an image  to "empty", marking the slot  available for another image.
   *
   * input: ver_id
   * output: none
   * return: error_t
   */

  command error_t IM.delete(image_ver_t ver_id) {
    image_dir_t *dir;
    image_dir_slot_t *sp;
    error_t err;

    if (imcb.im_state != IMS_IDLE) {
      im_panic(13, imcb.im_state, 0);
      return FAIL;
    }

    /* dir_find_ver does the call to verify_IM */
    sp  = call IM.dir_find_ver(ver_id);
    if (!sp) {
      im_panic(14, imcb.im_state, 0);
      return FAIL;
    }
    sp->slot_state = SLOT_EMPTY;
    dir = &imcb.dir;
    dir->chksum = 0 - call Checksum.sum32_aligned((void *) dir, sizeof(*dir));
    imcb.im_state = IMS_DELETE_SYNC_REQ_SD;
    err = call SDResource.request();
    if (err) {
      im_panic(15, err, 0);
      return FAIL;
    }
    return SUCCESS;
  }


  /*
   * dir_find_ver: Returns a pointer to the slot for given image version.
   *
   * input: ver_id
   * output: none
   * return: dir_find_ver(ver_id)
   */

  command image_dir_slot_t *IM.dir_find_ver(image_ver_t ver_id) {
    image_dir_t *dir;
    image_dir_slot_t *sp;
    int i;

    dir = &imcb.dir;
    verify_IM();
    for (i = 0; i < IMAGE_DIR_SLOTS; i++) {
      sp = &dir->slots[i];
      if ((sp->slot_state >= SLOT_VALID) &&
          cmp_ver_id(&(sp->ver_id), &ver_id))
        return sp;
    }
    return NULL;
  }


  command bool IM.dir_coherent() {
    return imcb.im_state == IMS_IDLE;
  }


  /*
   * dir_get_active: find current active if any
   *
   * input:  none
   * return: ptr        slot entry for current active.
   *                    NULL if no active image
   */
  command image_dir_slot_t *IM.dir_get_active() {
    image_dir_slot_t *ap;

    verify_IM();
    get_active_backup(&ap, NULL);
    return ap;
  }


  /*
   * dir_get_dir: Returns a pointer to the dir slot indexed by idx
   *
   * input:  idx
   * output: image_dir_slot_t
   * return:
   */

  command image_dir_slot_t *IM.dir_get_dir(uint8_t idx) {
    verify_IM();
    if (idx >= IMAGE_DIR_SLOTS)
      return NULL;
    return &imcb.dir.slots[idx];
  }


  /*
   * dir_set_active: Verifies that one image in directory is set as valid,
   *                 Sets the image state to Active for given ver_id.
   *
   * input: ver_id
   * output: none
   * return: error_t
   *
   * start a cache flush
   */
  command error_t IM.dir_set_active(image_ver_t ver_id) {
    error_t err;
    image_dir_t *dir;
    image_dir_slot_t *newp, *active;

    if (imcb.im_state != IMS_IDLE) {
      im_panic(22, imcb.im_state, 0);
      return FAIL;
    }

    /* dir_find_ver does the call to verify_IM */
    newp = call IM.dir_find_ver(ver_id);

    /*
     * the image being proposed for the new active needs to exist
     * and must be in the VALID state.
     */
    if ((!newp) || (newp->slot_state != SLOT_VALID)) {
      im_panic(23, imcb.im_state, (parg_t) newp);
      return FAIL;
    }

    /* If we have an active, switch it to backup */
    get_active_backup(&active, NULL);
    if (active)
      active->slot_state = SLOT_BACKUP;

    newp->slot_state = SLOT_ACTIVE;
    dir = &imcb.dir;
    dir->chksum = 0 - call Checksum.sum32_aligned((void *) dir, sizeof(*dir));

    /*
     * directory has been updated.  Fire up a dir flush
     */
    imcb.im_state = IMS_DSA_SYNC_REQ_SD;
    if ((err = call SDResource.request()))
      im_panic(24, err, 0);
    return SUCCESS;
  }


  /*
   * dir_set_backup: set the specified image to BACKUP
   *
   * Image has to be present and VALID.  Will not change any other state
   * to BACKUP.
   *
   * Forces a dir sync.
   */
  command error_t IM.dir_set_backup(image_ver_t ver_id) {
    error_t err;
    image_dir_t *dir;
    image_dir_slot_t *newp, *ap;

    if (imcb.im_state != IMS_IDLE) {
      im_panic(22, imcb.im_state, 0);
      return FAIL;
    }

    /* dir_find_ver does the call to verify_IM */
    newp = call IM.dir_find_ver(ver_id);

    /*
     * setting backup, make sure we have an active
     * It doesn't make sense to have a BACKUP and no ACTIVE
     * yell and scream.  This is a sanity check.
     */
    get_active_backup(&ap, NULL);

    /*
     * the image requested to set as  backup needs to exist
     * and must be in the VALID state.
     */
    if (!ap || !newp || (newp->slot_state != SLOT_VALID)) {
      im_panic(23, (parg_t) newp, (parg_t) ap);
      return FAIL;
    }
    newp->slot_state = SLOT_BACKUP;
    dir = &imcb.dir;
    dir->chksum = 0 - call Checksum.sum32_aligned((void *) dir, sizeof(*dir));

    /*
     * directory has been updated.  Fire up a dir flush
     */
    imcb.im_state = IMS_DSB_SYNC_REQ_SD;
    if ((err = call SDResource.request()))
      im_panic(24, err, 0);
    return SUCCESS;
  }


  /*
   * dir_eject_active: throw the current active out.
   *
   * there needs to be an active to throw out.  Move it to
   * EJECTED state.  If there is also a BACKUP then move that
   * to the ACTIVE state.
   *
   * Sync the directory.
   */
  command error_t IM.dir_eject_active() {
    error_t err;
    image_dir_t *dir;
    image_dir_slot_t *active, *backup;

    if (imcb.im_state != IMS_IDLE) {
      im_panic(22, imcb.im_state, 0);
      return FAIL;
    }

    verify_IM();
    get_active_backup(&active, &backup);
    if (!active) {
      im_panic(23, (parg_t) active, (parg_t) backup);
      return FAIL;
    }
    active->slot_state = SLOT_EJECTED;
    if (backup)
      backup->slot_state = SLOT_ACTIVE;

    dir = &imcb.dir;
    dir->chksum = 0 - call Checksum.sum32_aligned((void *) dir, sizeof(*dir));

    /*
     * directory has been updated.  Fire up a dir flush
     */
    imcb.im_state = IMS_EJECT_SYNC_REQ_SD;
    if ((err = call SDResource.request()))
      im_panic(24, err, 0);
    return SUCCESS;
  }


  /*
   * finish: an image is finished.
   *
   * o make sure any remainging data is written to the slot from the working buffer.
   * o Mark image as valid.
   * o sync the directory.
   *
   * input:  none
   * output: none
   * return: error_t
   */

  command error_t IM.finish() {
    error_t err;
    image_dir_t *dir;

    if (imcb.im_state != IMS_FILL_WAITING) {
      im_panic(24, imcb.im_state, 0);
      return FAIL;
    }
    verify_IM();
    imcb.filling_slot_p->slot_state = SLOT_VALID;
    dir = &imcb.dir;
    dir->chksum = 0 - call Checksum.sum32_aligned((void *) dir, sizeof(*dir));

    /*
     * if there are no bytes in the IMWB then immediately transition
     * to writing/syncing the dir cache to the directory.
     */
    if (imcb.bytes_remaining == SD_BLOCKSIZE)
      imcb.im_state = IMS_FILL_SYNC_REQ_SD;
    else imcb.im_state = IMS_FILL_LAST_REQ_SD;
    err = call SDResource.request();
    if (err) {
      im_panic(24, err, 0);
      return FAIL;
    }
    return SUCCESS;
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

  command uint32_t IM.write(uint8_t *buf, uint32_t len) {
    uint32_t copy_len;
    uint32_t bytes_left;
    error_t  err;

    if (imcb.im_state != IMS_FILL_WAITING) {
      im_panic(25, imcb.im_state, 0);
      return 0;
    }

    verify_IM();
    if (len <= imcb.bytes_remaining) {
      copy_len = len;
      imcb.bytes_remaining -= len;
      bytes_left = 0;
    } else {
      copy_len = imcb.bytes_remaining;
      imcb.bytes_remaining = 0;
      bytes_left = len - copy_len;
    }

    memcpy(imcb.buf_ptr, buf, copy_len);
    imcb.buf_ptr += copy_len;
    if (bytes_left) {
      imcb.im_state = IMS_FILL_REQ_SD;
      err = call SDResource.request();
      if (err) {
        im_panic(26, err, 0);
        return FAIL;
      }
    }
    return bytes_left;
  }


  event void SDResource.granted() {
    error_t err;

    switch(imcb.im_state) {
      default:
        im_panic(28, imcb.im_state, 0);
        return;

      case IMS_INIT_REQ_SD:
        imcb.im_state = IMS_INIT_READ_DIR;
        err = call SDread.read(imcb.region_start_blk, im_wrk_buf);
        if (err) {
          im_panic(29, err, 0);
          return;
        }
        return;

      case IMS_FILL_REQ_SD:
        imcb.im_state = IMS_FILL_WRITING;
        write_slot_blk();
        return;

      case IMS_FILL_LAST_REQ_SD:
        imcb.im_state = IMS_FILL_LAST_WRITE;
        write_slot_blk();
        return;

      case IMS_FILL_SYNC_REQ_SD:
        imcb.im_state = IMS_FILL_SYNC_WRITE;
        write_dir_cache();
        return;

      case IMS_DELETE_SYNC_REQ_SD:
        imcb.im_state = IMS_DELETE_SYNC_WRITE;
        write_dir_cache();
        return;

      case  IMS_DSA_SYNC_REQ_SD:
        imcb.im_state = IMS_DSA_SYNC_WRITE;
        write_dir_cache();
        return;

      case  IMS_DSB_SYNC_REQ_SD:
        imcb.im_state = IMS_DSB_SYNC_WRITE;
        write_dir_cache();
        return;

      case  IMS_EJECT_SYNC_REQ_SD:
        imcb.im_state = IMS_EJECT_SYNC_WRITE;
        write_dir_cache();
        return;
    }
  }


  event void SDread.readDone(uint32_t blk_id, uint8_t *read_buf, error_t err) {
    image_dir_t *dir;
    int i;

    dir = &imcb.dir;
    if (imcb.im_state != IMS_INIT_READ_DIR) {
      im_panic(30, imcb.im_state, err);
      return;
    }

    /*
     * we just completed reading the directory sector.
     *
     * check for all zeroes.  If so we need to initialize the
     * directory to empty with proper start_sec fields.
     */
    nop();
    if (chk_zero(im_wrk_buf, SD_BLOCKSIZE)) {
      dir->dir_sig   = IMAGE_DIR_SIG;
      dir->dir_sig_a = IMAGE_DIR_SIG;
      for (i = 0; i < IMAGE_DIR_SLOTS; i++)
        dir->slots[i].start_sec =
          imcb.region_start_blk + ((IMAGE_SIZE_SECTORS * i) + 1);

      dir->chksum = 0 - call Checksum.sum32_aligned((void *) dir, sizeof(*dir));
      imcb.im_state = IMS_INIT_SYNC_WRITE;
      write_dir_cache();
      return;
    }

    /*
     * non-zero directory sectory, read in the directory and
     * check for validity.
     */
    memcpy(dir, im_wrk_buf, sizeof(*dir));
    verify_IM();

    imcb.im_state = IMS_IDLE;
    call SDResource.release();
    signal Booted.booted();
    return;
  }


  event void SDwrite.writeDone(uint32_t blk, uint8_t *buf, error_t error) {
    switch(imcb.im_state) {
      default:
        im_panic(33, imcb.im_state, 0);
        return;

      case IMS_INIT_SYNC_WRITE:
        imcb.im_state = IMS_IDLE;
        call SDResource.release();
        signal Booted.booted();
        return;

      case IMS_FILL_WRITING:
        imcb.im_state = IMS_FILL_WAITING;
        imcb.filling_blk++;
        call SDResource.release();
        signal IM.write_continue();
        return;

      case IMS_FILL_LAST_WRITE:
        imcb.im_state = IMS_FILL_SYNC_WRITE;
        write_dir_cache();
        return;

      case IMS_FILL_SYNC_WRITE:
        imcb.im_state = IMS_IDLE;
        imcb.buf_ptr = NULL;
        imcb.filling_slot_p = NULL;
        call SDResource.release();
        signal IM.finish_complete();
        return;

      case IMS_DELETE_SYNC_WRITE:
        imcb.im_state = IMS_IDLE;
        call SDResource.release();
        signal IM.delete_complete();
        return;

      case IMS_DSA_SYNC_WRITE:
        imcb.im_state = IMS_IDLE;
        call SDResource.release();
        signal Booted.booted();         /* this is wrong */
        signal IM.dir_set_active_complete();
        return;

      case  IMS_DSB_SYNC_WRITE:
        imcb.im_state = IMS_IDLE;
        call SDResource.release();
        signal IM.dir_set_backup_complete();
        return;

      case IMS_EJECT_SYNC_WRITE:
        imcb.im_state = IMS_IDLE;
        call SDResource.release();
        signal IM.dir_eject_active_complete();
        return;
    }
  }

  async event void Panic.hook() { }
}
