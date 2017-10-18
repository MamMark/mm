/*
 * Copyright (c) 2017 Eric B. Decker
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

/*
 * OverWatch to underlying hardware interface
 */

#include <image_info.h>

interface OverWatchHardware {
  /*
   * return a compacted Reset Status from the hardware.
   * clears any understood bits from the hardware.
   *
   * this is used for reporting status after a reset/reboot.
   * layout is h/w dependent.  See tos/<platform>/hardware/OWHardwareM.nc
   *
   * ResetOther is used for obtaining any other reset status bits that
   * we currently don't recognize (listed as reserved when this code was
   * written).  Should always be reported as 0.
   */
  async command uint32_t getResetStatus();
  async command uint32_t getResetOthers();

  /*
   * launch an image, typically a NIB region.
   *
   * if it fails just return.
   */
  async command void boot_image(image_info_t *iip);

  /*
   * fake_reset: simulate a reset
   *
   * fake_reset is used when we don't want to do the real reset
   * but rather we do want some of the functionality.
   *
   * typically used when debugging reset problems.
   */
  async command void fake_reset();

  /*
   * getImageBase: return base address of the image
   *
   * Where did the current executing image load.?
   */
  async command uint32_t getImageBase();

  /*
   * flash access.
   */
  async command error_t flashProtectAll();

  /* erase flash */
  async command error_t flashErase(uint8_t *start, uint32_t len);

  /* program flash */
  async command error_t flashProgram(uint8_t *src, uint8_t *fdest, uint32_t len);
}
