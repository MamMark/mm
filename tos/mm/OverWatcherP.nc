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
 * OverWatcherP
 *
 * This is the TinyOS module providing the primary Overwatch TinyOS
 * functionality.  Minimal low level functions are provided by OWL
 * (OverWatch Lowlevel) but those are kept to a minimum.  Higher level
 * functionality is provided by OWT (OverWatch Tinyos) and that
 * functionality is provided by this module.
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
 */

module OverWatcherP {
  provides {
    interface         Overwatch;
    interface Boot as OwBooted;           /* outBoot */
  }
  uses {
    interface         Boot;               /* inBoot */
  }
}
implementation {

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
    /*
     * VTOR being 0 tells us we are running in the OW bank
     * anything else and we are running from the NIB space.
     */
    if (VTOR == 0) {
      if (ow_control_block.owt_boot_mode == OW_BOOT_GOLD)
        signal OwGoldBoot.booted();
      // else initialize for OWT processing
    }
    // else initialize for NIB
  }

  /*
   * Install - Load and execute new software image
   *
   * Expects that the current Image Directory is valid and
   * reflects the desired state of images.
   * The Image Directory can contain zero or one image in
   * the Active state and zero or one image in the Backup
   * state. The directory may contain additional images but
   * these are irrelevant to OverWatcher.
   * An image marked as Active should be used to load the NIB
   * Flash (Bank 1).
   * An image marked as Backup should be used if the Active
   * image has exceeded the failure threshold.
   * If there is no Active image, the current NIB Flash (Bank
   * 1) is added to the Image directory and copied to SD.
   * If there is no Backup image when reboot failure threshold
   * has been exceeded, then run Golden.

   */
  command error_t Overwatch.Install() {
  }

  /*
   * ForceBoot - Request boot into specific mode
   *
   * Request OverWatcher (the Overwatcher low level) to select
   * a specific image and mode (OWT, GOLD, NIB).
   * The OWT and GOLD are part of the same image (in bank 0)
   * and are installed at the factory.
   * The NIB contains the current Active image (in bank 1)
   * found in the SD storage.
   */
  command void Overwatch.ForceBoot(ow_boot_mode_t boot_mode) {
  }

  /*
   * Fail - Request reboot of current running image
   *
   * Request OverWatcher to handle a failure of the currently
   * running image.
   * OverWatcher low level counts the failure and checks for
   * exceeding a failure threshold of faults per unit of time.
   * If exceeded, then low level initiates OWT to eject the
   * current Active image and replace with the Backup image.
   * If no backup, then just run Golden.
   * The reasons for failure include various exceptions as
   * well as panic().
   */
  command void Overwatch.Fail(ow_reboot_reason_t reason) {
  }
