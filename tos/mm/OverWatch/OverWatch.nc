/*
 * Copyright (c) 2017 Daniel Maltbie, Eric B. Decker
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

#include <image_mgr.h>
#include <overwatch.h>

/* move interface descriptions over to the implementation */

interface OverWatch {
  /**
   * Install
   *
   * Request the Overwatcher to load a new active image. The
   * new image should already have been written to the SD and the
   * directory entry marked as active. Otherwise, it will effectively
   * reboot the system.
   *
   */
  command void install();


  /**
   * ForceBoot
   *
   * This will force the Overwatcher to boot the system into the
   * specified boot instance (OWT, GOLD, NIB).
   *
   * @param   boot_mode     which image instance to boot into
   * @return  error_t
   */
  command void force_boot(ow_boot_mode_t boot_mode);


  /**
   * Fail
   *
   * Request the Overwatcher handle a runtime failure of the provided
   * reboot reason type. Overwatcher will determine if the currently
   * running instance has exceeded a failure threshold (too many
   * failures per unit of time) and cause a fall back to the backup
   * (previously active) mage. If no backup image is available then
   * Overwatch will start Golden.
   *
   * @param   reason        failure reason, most likely a panic or unhandled interrupt
   */
  command void fail(ow_reboot_reason_t reason);

  command ow_reboot_reason_t getRebootReason();
  command ow_boot_mode_t     getBootMode();

  command uint32_t getElapsedUpper();
  command uint32_t getElapsedLower();
  command uint32_t getBootcount();
  command void                clearReset();
}
