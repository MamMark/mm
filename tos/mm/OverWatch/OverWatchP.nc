/*
 * Copyright (c) 2017 Daniel J Maltbie, Eric B. Decker
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

#include <sd.h>
#include <image_info.h>
#include <image_mgr.h>
#include <overwatch.h>
#include <overwatch_hw.h>

extern ow_control_block_t ow_control_block;

/*
 * OverWatchP
 *
 * This is the TinyOS module providing OverWatch TinyOS functionality.
 * Minimal low level functions are provided by OWL (OverWatch Lowlevel) but
 * those are kept to a minimum.  Higher level functionality is provided by
 * OWT (OverWatch Tinyos) and that functionality is provided by this
 * module.
 *
 * OWL runs very early in the initial startup code (startup.c) after a full
 * PowerOn Reset (POR) occurs.  (the critical trigger is the zeroing of VTOR,
 * Vector Table Offset Register).  OWL is responsible for very early dispatch
 * when that is called for.  Dispatch determines if the NIB should be run
 * and if so loads the NIB SP and NIB Reset Vector.
 *
 * OWT is responsbile for implementing the actions requested via the
 * owt_action control cell.  This includes the following functions:
 *
 * ACT_INIT
 * ACT_INSTALL
 * ACT_EJECT
 *
 * If no action is requested, we will boot the golden image.
 *
 * WARNING: OverWatch T (OWT) runs prior to the main system being up.
 * It can not call Panic when something goes wrong.  It can only
 * indicate something strange by tweaking the stange cell in the OW
 * control block.
 */

volatile uint32_t ow_t0, ow_t1, ow_d0;

module OverWatchP {
  provides {
    interface Boot as Booted;           /* outBoot */
    interface OverWatch;
  }
  uses {
    interface Boot;                     /* inBoot */
    interface SysReboot;
    interface Checksum;
    interface ImageManager as IM;
    interface OverWatchHardware as OWhw;
    interface Platform;
  }
}
implementation {

  uint8_t *owt_ptr;
  uint32_t owt_len;
  uint32_t owt_len_to_send = 128;

  /*
   * good_nib_vectors: verify nib vectors
   *
   * Quick verification of some sense of reasonableness before launching
   * the NIB  image.
   *
   * 1) Verify the signature of the image_info block.
   * 2) extract the vector checksum, vector_chk
   * 3) calculate vector across the vector table.
   * 4) add vector_chk.  result should be zero.
   *
   * Note: if iip->vector_chk is 0, we currently assume the checksum is
   * disabled.
   */
  bool good_nib_vectors(image_info_t *iip) {
    uint32_t vec_sum;

    if (iip->sig != IMAGE_INFO_SIG)
      return FALSE;
    if (iip->vector_chk) {
      vec_sum = call Checksum.sum32_aligned((void *) NIB_BASE,
                                            NIB_VEC_BYTES);
      vec_sum += iip->vector_chk;
      if (vec_sum) {
        ow_control_block.vec_chk_fail++;
        return FALSE;
      }
    }
    return TRUE;
  }


  /*
   * good_nib_flash: verify nib flash
   *
   * Check the NIB image.  Verify its checksum.
   *
   * 1) Verify the signature of the image_info block.
   * 2) extract the image size from the structure.  This is in bytes.
   * 3) calculate the checksum across the entire image.
   *
   * The checksum is embedded and is automatically included in the
   * sum.  The checksum must result in zero to pass.
   *
   * Note: if iip->image_chk is 0, we currently assume the checksum is
   * disabled.
   */
  bool good_nib_flash(image_info_t *iip) {
    uint32_t image_sum;

    if (iip->sig != IMAGE_INFO_SIG)
      return FALSE;
    if (iip->image_chk) {
      image_sum = call Checksum.sum32_aligned((void *) NIB_BASE,
                                              iip->image_length);
      if (image_sum) {
        ow_control_block.image_chk_fail++;
        return FALSE;
      }
    }
    return TRUE;
  }


  void init_owcb(ow_control_block_t *owcp) {
    memset(owcp, 0, sizeof(*owcp));
    owcp->ow_sig_a = owcp->ow_sig_b = owcp->ow_sig_c = OW_SIG;
    owcp->reboot_reason = ORR_OWCB_CLOBBER;
    owcp->from_base     = OW_BASE_UNK;          /* mark as unknown */
    owcp->reset_status  = call OWhw.getResetStatus();
    owcp->reset_others  = call OWhw.getResetOthers();
  }


  bool valid_owcb(ow_control_block_t *owcp) {
    if (owcp->ow_sig_a == OW_SIG &&
        owcp->ow_sig_b == OW_SIG &&
        owcp->ow_sig_c == OW_SIG)
      return TRUE;
    return FALSE;
  }


  /*
   * handle startup conditions for OverWatch.  Called from startup code
   *
   * We prevent name mangling so we can call it from startup.
   */
  void owl_startup() @C() @spontaneous() {
    image_info_t       *iip;
    ow_control_block_t *owcp;

    /*
     * if non-zero VTOR we are running as the NIB then simply return.
     * OverWatch is a Base region function only.
     *
     * ImageBase 0?  -> yes then golden
     *                  no  then other, ie.  NIB  (normal image block)
     */
    owcp = &ow_control_block;
    if (call OWhw.getImageBase()) {                     /* from NIB? */
      if (!valid_owcb(owcp)) {
        /*
         * PANIC
         *
         * but for now reinit and strange it.
         */
        init_owcb(owcp);
        owcp->strange++;
        owcp->strange_loc = 0x101;
        call OverWatch.force_boot(OW_BOOT_GOLD);
      }
      return;
    }

    /*
     * first check to see if the control block seems intact.
     */
    if (!valid_owcb(owcp)) {
      /*
       * oops.  The control block has been slammed.  We need to fire up OWT
       * so we can ask the ImageManager to figure out what exactly we should
       * do.
       *
       * 1) reinitialize the control block
       * 2) invoke OWT for OWT_INIT
       */
      init_owcb(owcp);
      owcp->ow_boot_mode  = OW_BOOT_OWT;
      owcp->owt_action    = OWT_ACT_INIT;
      return;
    }
    owcp->reset_status  = call OWhw.getResetStatus();
    owcp->reset_others  = call OWhw.getResetOthers();

    /*
     * control block is valid, normal start up.
     * See if there are any requests
     */
    switch (owcp->ow_req) {
      default:
        /*
         * kill sig and reboot
         * serious oht oh.  sigs are okay but ow_req is out of bounds.
         */
        owcp->strange++;
        owcp->strange_loc = 1;
        call OverWatch.force_boot(OW_BOOT_GOLD);
        return;
        return;

      case OW_REQ_BOOT:
        /*
         * Use ow_boot_mode to determine where we are going.
         */
        switch (owcp->ow_boot_mode) {
          default:
            /*
             * oops.  things are screwed up.  no where to go.
             * so just fix it so something runs.
             */
            owcp->strange++;
            owcp->strange_loc = 2;
            call OverWatch.force_boot(OW_BOOT_GOLD);
            return;

          case OW_BOOT_GOLD:
          case OW_BOOT_OWT:
            return;

          case OW_BOOT_NIB:
            /*
             * If we are booting the NIB, we want to first check
             * the NIBs validity.  If good_nib_flash takes too long
             * we can switch to checking the vector table instead.
             */
            iip  = (image_info_t *) NIB_INFO;
            if (good_nib_vectors(iip) && good_nib_flash(iip)) {
              /*
               * if it returns, boot GOLD
               */
              call OWhw.boot_image(iip);
              owcp->strange++;
              owcp->strange_loc = 3;
              call OverWatch.force_boot(OW_BOOT_GOLD);
              return;                   /* shouldn't get here. */
            }

            /*
             * oops.  nib didn't check out.  shitty NIB checksum.
             */
            owcp->strange++;
            owcp->strange_loc = 4;
            call OverWatch.force_boot(OW_BOOT_GOLD);
            return;
        }

      case OW_REQ_INSTALL:
        owcp->ow_req = OW_REQ_BOOT;
        owcp->ow_boot_mode = OW_BOOT_OWT;
        owcp->owt_action = OWT_ACT_INSTALL;
        return;

      case OW_REQ_FAIL:                 /* crash, rebooting */
        owcp->ow_req = OW_REQ_BOOT;

        /*
         * this needs to be modified to handle overflow etc.  probably
         * just modify for uint64_t will do it.
         */
        owcp->elapsed_lower += owcp->time;
        owcp->elapsed_upper += owcp->cycle;
        owcp->reboot_count++;

        if (from_nib) {
          if (owcp->reboot_count > 10) {
            owcp->ow_boot_mode = OW_BOOT_OWT;
            owcp->owt_action = OWT_ACT_EJECT;

            /* continue boot, normal */
            return;
          }
          iip  = (image_info_t *) NIB_INFO;
          call OWhw.boot_image(iip);
          call OverWatch.force_boot(OW_BOOT_GOLD);
          return;                   /* shouldn't get here. */
        }
        owcp->strange++;
        owcp->strange_loc = 5;
    }
  }


  /*
   * Boot.booted - check booting mode for Golden, else OWT
   *
   * If not running in bank0, then initialize normally for NIB.
   * If boot mode is Golden, then continue the booting to
   * initialize additional drivers and modules.
   * Else start up restricted mode OWT.
   *
   * OWT operating mode expects that the boot initialization
   * chain executed prior is the minimal set of drivers and
   * modules required. Any additional drivers and modules
   * should be added downstream on GoldBooted.
   */
  event void Boot.booted() {
    ow_control_block_t *owcp;
    image_dir_slot_t   *active;
    image_info_t       *iip;
    uint32_t remaining;
    error_t err;

    owcp = &ow_control_block;
    if (owcp->ow_boot_mode != OW_BOOT_OWT) {
      signal Booted.booted();
      return;
    }
    switch (owcp->owt_action) {
      case OWT_ACT_NONE:
        owcp->strange++;
        owcp->strange_loc = 6;
        call OverWatch.force_boot(OW_BOOT_GOLD);
        return;

      case OWT_ACT_INIT:
        /*
         * 1) get IM.active -> ver
         * 2) check NIB for valid  -> no match
         * 3) check NIB for active ver -> no match
         * if match then force_boot(boot_nib)
         *
         * no match,
         */
        active = call IM.dir_get_active();
        if (!active) {
          /*
           * no active, we need to rectify that.
           *
           * We need to check the NIB to see if it is valid
           * We can check the image_chksum for validity.
           * Note, 0 says checksums aren't turned on, ignore
           * them.
           *
           * If the NIB is bad, then just boot GOLD.
           */
          iip = (void *) NIB_INFO;
          if (!good_nib_vectors(iip) || !good_nib_flash(iip)) {
            owcp->strange++;
            owcp->strange_loc = 7;
            call OverWatch.force_boot(OW_BOOT_GOLD);
            /* shouldn't return from the above */
            return;
          }

          /*
           * good NIB, no active, copy the NIB into an image
           * slot using the ImageManager.  Verify it will fit.
           */
          if (!call IM.check_fit(iip->image_length)) {
            owcp->strange++;
            owcp->strange_loc = 8;
            call OverWatch.force_boot(OW_BOOT_GOLD);
            return;
          }
          err = call IM.alloc(iip->ver_id);
          if (err) {
            owcp->strange++;
            owcp->strange_loc = 9;
            call OverWatch.force_boot(OW_BOOT_GOLD);
            return;
          }
          nop();
          ow_t0 = call Platform.usecsRaw();
          owt_ptr = (void *) iip->image_start;
//            owt_len = iip->image_length;
          owt_len = 128 * 1024;

          remaining = call IM.write(owt_ptr, owt_len);
          if (!remaining) {
            call IM.finish();
            return;
          }
          owt_ptr += (owt_len - remaining);
          owt_len = remaining;
          return;

#ifdef notdef
          while (owt_len) {
            remaining = call IM.write(owt_ptr, owt_len_to_send);
            if (remaining) {
              owt_ptr += (owt_len_to_send - remaining);
              owt_len -= (owt_len_to_send - remaining);
              return;
            }
            owt_len -= owt_len_to_send;
            owt_ptr += owt_len_to_send;
            if (owt_len_to_send > owt_len)
              owt_len_to_send = owt_len;
          }
          call IM.finish();
          return;
#endif
        }

        /*
         * We have a active, check the NIB and see if it
         * matches what the ImageManager thinks is the ACTIVE.
         */
        return;

      case OWT_ACT_INSTALL:
        /*
         * 1) get IM.active -> none strange
         *    ver and s0
         * 2) read 1st sector
         *    stash image info
         *      verify -> abort strange
         *        ver id, vector check
         *      start running checksum
         * 3) slam flash
         * 4) verify checksum -> abort strange
         * 5) OW.force_boot(NIB)
         */

      case OWT_ACT_EJECT:
        /*
         * IM.eject
         * <- eject complete
         * get IM.active
         *    -> none   force_boot(GOLD)
         * INSTALL
         */
    }
  }


  event void IM.write_continue() {
    uint32_t remaining;

    nop();
    nop();
    remaining = call IM.write(owt_ptr, owt_len);
    if (!remaining) {
      call IM.finish();
      return;
    }
    owt_ptr += (owt_len - remaining);
    owt_len = remaining;
    return;

#ifdef notdef
    while (owt_len) {
      remaining = call IM.write(owt_ptr, owt_len_to_send);
      if (remaining) {
        owt_ptr += (owt_len_to_send - remaining);
        owt_len -= (owt_len_to_send - remaining);
        return;
      }
      owt_len -= owt_len_to_send;
      owt_ptr += owt_len_to_send;
      if (owt_len_to_send > owt_len)
        owt_len_to_send = owt_len;
    }
    call IM.finish();
    return;
#endif
  }


  event void IM.finish_complete() {
    image_info_t *iip;

    ow_t1 = call Platform.usecsRaw();
    ow_d0 = ow_t1 - ow_t0;
    nop();
    iip = (void *) NIB_INFO;
    call IM.dir_set_active(iip->ver_id);
  }


  event void IM.dir_set_active_complete() {
    nop();
    call OverWatch.install();
  }


  /*
   * Install - Load and execute new software image
   *
   * Expects that the current Image Directory is valid and reflects the
   * desired state of images.
   *
   * The Image Directory can contain zero or one image in the Active state
   * and zero or one image in the Backup state. The directory may contain
   * additional images but these are irrelevant to OverWatch.  .  An image
   * marked as Active can be used to load the NIB Flash (Bank 1).
   *
   * An image marked as Backup can be used if the Active image has exceeded
   * the failure threshold.
   *
   * If there is no Active image, OWT_INIT will write the NIB (Bank 1) if
   * valid to the ImageManager and it will be set active.
   */

  command void OverWatch.install() {
    ow_control_block_t *owcp;

    owcp = &ow_control_block;
    owcp->ow_req = OW_REQ_INSTALL;
    owcp->from_base = call OWhw.getImageBase();
    call SysReboot.reboot(SYSREBOOT_OW_REQUEST);
  }


  /*
   * ForceBoot - Request boot into specific mode
   *
   * Request OverWatch (the Overwatcher low level) to select
   * a specific image and mode (OWT, GOLD, NIB).
   * The OWT and GOLD are part of the same image (in bank 0)
   * and are installed at the factory.
   * The NIB contains the current Active image (in bank 1)
   * found in the SD storage.
   */
  command void OverWatch.force_boot(ow_boot_mode_t boot_mode) {
    ow_control_block_t *owcp;

    owcp = &ow_control_block;
    owcp->ow_req = OW_REQ_BOOT;
    owcp->ow_boot_mode = boot_mode;
    owcp->reboot_reason = ORR_FORCED_MODE;
    owcp->from_base = call OWhw.getImageBase();
    call SysReboot.reboot(SYSREBOOT_OW_REQUEST);
  }


  /*
   * Fail - Request reboot of current running image
   *
   * Request OverWatcher to handle a failure of the currently
   * running image.
   *
   * OverWatch low level counts the failure and checks for
   * exceeding a failure threshold of faults per unit of time.
   * If exceeded, then low level initiates OWT to eject the
   * current Active image and replace with the Backup image.
   * If no backup, then just run Golden.
   * The reasons for failure include various exceptions as
   * well as panic().
   */
  command void OverWatch.fail(ow_reboot_reason_t reason) {
    ow_control_block_t *owcp;

    owcp = &ow_control_block;
    owcp->cycle = 0;
    owcp->time = 1000;                  /* just pretend for now */
    owcp->reboot_reason = reason;
    owcp->from_base = call OWhw.getImageBase();
    owcp->ow_req = OW_REQ_FAIL;
    call SysReboot.reboot(SYSREBOOT_OW_REQUEST);
  }


  /*
   * getBootMode: return current boot mode from control block
   */
  command ow_boot_mode_t OverWatch.getBootMode() {
    return ow_control_block.ow_boot_mode;
  }


  command void OverWatch.clearReset() {
    ow_control_block_t *owcp;

    owcp = &ow_control_block;
    owcp->reset_status  = 0;
    owcp->reset_others  = 0;
    owcp->reboot_reason = 0;
    owcp->from_base     = OW_BASE_UNK;
  }


  command ow_control_block_t *OverWatch.getControlBlock() {
    return &ow_control_block;
  }


  command uint32_t OverWatch.getImageBase() {
    return call OWhw.getImageBase();
  }


  event void IM.delete_complete() { }
  event void IM.dir_set_backup_complete()   { }
  event void IM.dir_eject_active_complete() { }

  async event void SysReboot.shutdown_flush() { }
}
