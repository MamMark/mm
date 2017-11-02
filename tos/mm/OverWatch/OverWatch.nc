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
  async command void install();


  /**
   * ForceBoot
   *
   * Request OverWatch to boot the system into the specified boot mode.
   * (OWT, GOLD, NIB).  This is also used to force a reboot.
   *
   * @param   boot_mode     which image instance to boot into
   * @param   reason        why the force_boot is being done
   * @return  error_t
   */
  async command void force_boot(ow_boot_mode_t boot_mode,
                                ow_reboot_reason_t reason);


  /**
   * Fail
   *
   * Tell OverWatch that this image has failed.
   *
   * OverWatch will determine if the currently running instance has
   * exceeded a failure threshold (too many failures per unit of time) and
   * cause a fall back to the backup (previously active image). If no
   * backup image is available then Overwatch will launch Golden.
   *
   * @param reason      failure reason, most likely a panic or unhandled
   *                    interrupt
   */
  async command void fail(ow_reboot_reason_t reason);

  async command void strange(uint32_t loc);

  async command ow_boot_mode_t      getBootMode();
  async command void                clearReset();
  async command ow_control_block_t *getControlBlock();

  async command uint32_t            getImageBase();
}
