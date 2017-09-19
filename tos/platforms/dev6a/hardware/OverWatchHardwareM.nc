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
 *
 * @author Eric B. Decker <cire831@gmail.com>
 */

extern ow_control_block_t ow_control_block;

module OverWatchHardwareM {
  provides interface OverWatchHardware as OWhw;
}
implementation {

  uint32_t others;

  /*
   * return a single 32 bit quantity that indicates the reset/reboot
   * status of the beasty.
   *
   * getResetStatus must be run prior to getting a valid value for
   * getResetOther.
   */
  command uint32_t OWhw.getResetStatus() {
    uint32_t cur, gather;

    cur    = RSTCTL->HARDRESET_STAT;
    RSTCTL->HARDRESET_CLR = cur;
    others = cur & ~(OW_HARD_SYSRESET_BIT  | OW_HARD_WD_TO_BIT |
                     OW_HARD_WD_PW_BIT     | OW_HARD_FLCTL_BIT |
                     OW_HARD_OW_REBOOT_BIT | OW_HARD_CS_BIT    |
                     OW_HARD_PCM_BIT);

    /* only look at the bits that we know about */
    cur   &= (OW_HARD_SYSRESET_BIT  | OW_HARD_WD_TO_BIT |
              OW_HARD_WD_PW_BIT     | OW_HARD_FLCTL_BIT |
              OW_HARD_OW_REBOOT_BIT | OW_HARD_CS_BIT    |
              OW_HARD_PCM_BIT);
    gather = cur;

    cur     = RSTCTL->SOFTRESET_STAT;
    RSTCTL->SOFTRESET_CLR = cur;
    others |= cur & ~(OW_SOFT_CPU_LOCKUP_BIT | OW_SOFT_SWD_TO_BIT |
                      OW_SOFT_SWD_PW_BIT);

    if (cur & OW_SOFT_CPU_LOCKUP_BIT) gather |= RST_CPU_LOCKUP;
    if (cur & OW_SOFT_SWD_TO_BIT)     gather |= RST_SWD_TO;
    if (cur & OW_SOFT_SWD_PW_BIT)     gather |= RST_SWD_PW;

    cur     = RSTCTL->PSSRESET_STAT;
    RSTCTL->PSSRESET_CLR = 1;
    others |= cur & ~(OW_PSS_SVSMH_BIT | OW_PSS_BGREF_BIT |
                      OW_PSS_VDDDET_BIT);

    if (cur & OW_PSS_SVSMH_BIT)       gather |= RST_SVSMH;
    if (cur & OW_PSS_BGREF_BIT)       gather |= RST_BGREF;
    if (cur & OW_PSS_VDDDET_BIT)      gather |= RST_VDDDET;

    cur     = RSTCTL->PCMRESET_STAT;
    RSTCTL->PCMRESET_CLR = 1;
    others |= cur & ~(OW_PCM_LPM35_BIT | OW_PCM_LPM45_BIT);

    if (cur & OW_PCM_LPM35_BIT)       gather |= RST_LPM35_EXIT;
    if (cur & OW_PCM_LPM45_BIT)       gather |= RST_LPM45_EXIT;

    cur     = RSTCTL->PINRESET_STAT;
    RSTCTL->PINRESET_CLR = 1;
    others |= cur & ~(OW_PIN_BIT);

    if (cur & OW_PIN_BIT)             gather |= RST_RSTNMI;

    cur     = RSTCTL->REBOOTRESET_STAT;
    RSTCTL->REBOOTRESET_CLR = 1;
    others |= cur & ~(OW_REBOOT_BIT);

    if (cur & OW_REBOOT_BIT)          gather |= RST_REBOOT;

    cur = RSTCTL->CSRESET_STAT;
    RSTCTL->CSRESET_CLR = 1;
    others |= cur & ~(OW_CS_DCORSHT_BIT);

    if (cur & OW_CS_DCORSHT_BIT)      gather |= RST_DCORSHT;

    return gather;
  }


  command uint32_t OWhw.getResetOthers() {
    return others;
  }


  void launch(uint32_t base) {
    __asm__ volatile (
      "  ldr sp, [r0] \n"
      "  ldr pc, [r0, #4] \n" );
  }


  /*
   * returns FAIL if we can't launch
   */
  command void OWhw.boot_image(image_info_t *iip) {
    if (iip->sig != IMAGE_INFO_SIG)
      return;
    launch(iip->image_start);
  }
}
