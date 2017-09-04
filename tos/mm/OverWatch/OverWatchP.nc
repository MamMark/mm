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
 * 32 bit checksum.
 *
 * perform a 32 bit wide Little endian checksum.  Yields a 32 bit result.
 *
 * Accesses are done 32 bits wide.  Since little endian, the fetch will
 * reverse the byte order from a strict byte access ordering.
 *
 * Buffer is required to be aligned to a 4 byte (32 bit) alignment.  If not
 * will return 0.
 *
 * Additional references will be 4 bytes wide (aligned), will be fetched
 * and byte swapped (ie. addr 4 will give us 7-6-5-4) and added to the sum.
 *
 * There may be some left over remanents.  Let's say we are at address
 * 0x100 with 2 bytes remaining.  We fetch 0x100, 103-102-101-100.  But we
 * only want 101 and 100 to be included in the sum.  So we AND the result
 * with 0x0000FFFF.
 *
 * This routine is written for 32 bit processors that have a memory system
 * optimized for 32 bit accesses.
 *
 * Initial alignment is forced to be aligned because dealing with startup
 * unaligned conditions is a royal pain and isn't needed in most cases.
 *
 */

uint32_t checksum32(uint8_t *buf, uint32_t len) {
  uint32_t  sum;
  uint32_t *ptr;
  uint32_t  last;
  uint32_t  mask;

  if ((uintptr_t) buf & 3)
    bkpt();

  if (!len || !buf || ((uintptr_t) buf) & 3)
    return 0;

  ptr = (void *) buf;
  while (len > 3) {
    sum += *ptr++;
    len -= 4;
  }
  if (len) {
    /*
     * ptr points at the long word that holds the remnant
     * ptr will still be aligned.
     *
     * 103-102-101-100: 0x000000FF 0x0000FFFF 0x00FFFFFF
     * remaining len             1       2        3
     */
    last = *ptr;
    mask = 0xffffffff >> ((4-len) * 8);
    sum += (last & mask);
  }
  return sum;
}


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
    signal Booted.booted();
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
