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

ow_control_block_t ow_control_block __attribute__ ((section(".overwatch_data")));


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
 */
bool good_nib_vectors() {
  image_info_t *iip;
  uint32_t      vec_sum;
  uint32_t     *vecs;
  int           i;

  iip  = (image_info_t *) NIB_INFO;
  if (iip->sig != IMAGE_INFO_SIG)
    return FALSE;
  vec_sum = 0;
  vecs = (uint32_t *) NIB_BASE;
  for (i = 0; i < NIB_VEC_COUNT; i++)
    vec_sum += vecs[i];
  vec_sum += iip->vector_chk;
  if (vec_sum) {
    ow_control_block.vec_chk_fail++;
    return FALSE;
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
 * The checksum is calulated using 32 bit wide accesses.  The last
 * access may not be evenly aligned (32 bit alignment).  The last
 * access will be anded to remove any extra bytes.  They are set to
 * zero.  Keep in mind that the last access is fetching 32 bits
 * and it is little endian.  The mask must compensate.
 *
 * The checksum must result in zero to pass.
 */
bool good_nib_flash() {
  image_info_t *iip;
  uint32_t      image_sum;
  uint32_t     *image;
  uint32_t      i, count, left;
  uint32_t      last;

  iip  = (image_info_t *) NIB_INFO;
  if (iip->sig != IMAGE_INFO_SIG)
    return FALSE;
  image_sum = 0;
  image = (uint32_t *) NIB_BASE;
  count = iip->image_length;
  left  = count & 0x3;
  count = count >> 2;
  for (i = 0; i < count; i++)
    image_sum += image[i];
  if (left) {
    last = image[i];
    last &= (0xffffffff << (left * 8));
    image_sum += last;
  }
  if (image_sum) {
    ow_control_block.image_chk_fail++;
    return FALSE;
  }
  return TRUE;
}


/*
 * handle startup conditions for OverWatch
 *
 * Only gets called if we are runnint in low Flash.  ie GoldenOW
 */
owls_rtn_t owl_startup() @C() @spontaneous() {
  ow_control_block_t *owcp;

  owcp = &ow_control_block;

  /*
   * first check to see if the control block seems intact.
   */
  if (owcp->ow_sig_a != OW_SIG ||
      owcp->ow_sig_b != OW_SIG ||
      owcp->ow_sig_c != OW_SIG) {

    /*
     * oops.  The control block has been slammed.  We need to fire up OWT
     * so we can ask the ImageManager to figure out what exactly we should
     * do.
     *
     * 1) reinitialize the control block
     * 2) invoke OWT for OWT_INIT
     */

    memset(owcp, 0, sizeof(*owcp));
    owcp->ow_sig_a = owcp->ow_sig_b = owcp->ow_sig_c = OW_SIG;
    owcp->last_reboot_reason = ORR_PWR_FAIL;
    owcp->ow_boot_mode = OW_BOOT_OWT;
    owcp->owt_action   = OWT_ACT_INIT;
    return OWLS_CONTINUE;
  }

  /*
   * control block is valid, normal start up.
   * See if there are any requests
   */
  switch (owcp->ow_req) {
    default:
      /*
       * kill sig and reboot
       */
      return OWLS_CONTINUE;

    case OW_REQ_BOOT:
      /*
       * Use ow_boot_mode to determine where we are going.
       */
      switch (owcp->ow_boot_mode) {
        default:
          /*
           * oops.  things are screwed up.  no where to go.
           * so just fix it.
           */
          owcp->ow_boot_mode = OW_BOOT_GOLD;
          owcp->strange++;

          /* fall through */

        case OW_BOOT_GOLD:
        case OW_BOOT_OWT:
          return OWLS_CONTINUE;

        case OW_BOOT_NIB:
          /*
           * If we are booting the NIB, we want to first check
           * the NIBs validity.  If good_nib_flash takes too long
           * we can switch to checking the vector table instead.
           */
          if (good_nib_flash())
            return OWLS_BOOT_NIB;

          /*
           * oops.  nib didn't check out.
           */
          owcp->strange++;
          owcp->ow_boot_mode = OW_BOOT_GOLD;
          return OWLS_CONTINUE;
      }

    case OW_REQ_INSTALL:
      owcp->ow_req = OW_REQ_BOOT;
      owcp->ow_boot_mode = OW_BOOT_OWT;
      owcp->owt_action = OWT_ACT_INSTALL;
      return OWLS_CONTINUE;

    case OW_REQ_REBOOT:                /* crash, rebooting */
      owcp->ow_req = OW_REQ_BOOT;
      owcp->last_reboot_reason = owcp->reboot_reason;

      /* this needs to be modified to handle overflow etc.  probably
       * just modify for uint64_t will do it.
       */
      owcp->elapsed_lower += owcp->time;
      owcp->elapsed_upper += owcp->cycle;
      owcp->reboot_count++;

      if (owcp->ow_from_nib) {
        owcp->ow_from_nib = 0;
        if (owcp->reboot_count > 10) {
          owcp->ow_boot_mode = OW_BOOT_OWT;
          owcp->owt_action = OWT_ACT_EJECT;
          return OWLS_CONTINUE;
        }
        return OWLS_BOOT_NIB;
      }
      return OWLS_CONTINUE;
  }
}


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

module OverWatchP {
  provides {
    interface Boot as Booted;           /* outBoot */
    interface OverWatch;
  }
  uses {
    interface         Boot;             /* inBoot */
    interface         ImageManager as IM;
    interface         SysReboot;
  }
}
implementation {

  uint8_t *owt_ptr;
  uint32_t owt_len;

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
    image_info_t       *info;
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
        owcp->ow_boot_mode  = OW_BOOT_GOLD;
        owcp->reboot_reason = ORR_BAD_OWT_ACT;
        call SysReboot.reboot(SYSREBOOT_OW_REQUEST);
        return;

      case OWT_ACT_INIT:
        owcp->owt_action = OWT_ACT_NONE;
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
          info = (void *) NIB_INFO;
          err = call IM.alloc(info->ver_id);
          if (err) {
            call OverWatch.force_boot(OW_BOOT_GOLD);
            return;
          }
          owt_ptr = (void *) NIB_BASE;
          owt_len = 128 * 1024;
          remaining = call IM.write(owt_ptr, owt_len);
          if (!remaining) {
            call IM.finish();
            return;
          }
          owt_ptr += (owt_len - remaining);
          owt_len = remaining;
          return;
        }

      case OWT_ACT_INSTALL:
        owcp->owt_action = OWT_ACT_NONE;
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
        owcp->owt_action = OWT_ACT_NONE;
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

    remaining = call IM.write(owt_ptr, owt_len);
    if (!remaining) {
      call IM.finish();
      return;
    }
    owt_ptr += (owt_len - remaining);
    owt_len = remaining;
  }


  event void IM.finish_complete() {
    image_info_t *info;

    info = (void *) NIB_INFO;
    call IM.dir_set_active(info->ver_id);
  }


  event void IM.dir_set_active_complete() {
    call OverWatch.force_boot(OW_BOOT_NIB);
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
    owcp->ow_req = OW_REQ_REBOOT;
    call SysReboot.reboot(SYSREBOOT_OW_REQUEST);
  }

  command ow_reboot_reason_t OverWatch.getRebootReason() {
    return ow_control_block.last_reboot_reason;
  }

  /*
   * getBootMode: return current boot mode from control block
   */
  command ow_boot_mode_t OverWatch.getBootMode() {
    return ow_control_block.ow_boot_mode;
  }


  command uint32_t OverWatch.getElapsedUpper() { return 0; }
  command uint32_t OverWatch.getElapsedLower() { return 0; }
  command uint32_t OverWatch.getBootcount()    { return 0; }
  command void OverWatch.clearReset() {
    ow_control_block_t *owcp;

    owcp = &ow_control_block;
    owcp->hard_reset = 0;
    owcp->reboot_reason = 0;
    RSTCTL->HARDRESET_CLR = 0xFFFFFFFF; /* clear all */
  }

  event void IM.delete_complete() { }
  event void IM.dir_eject_active_complete() { }

  async event void SysReboot.shutdown_flush() { }
}
