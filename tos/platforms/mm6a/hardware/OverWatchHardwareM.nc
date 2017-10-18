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

#include <overwatch.h>
#include <overwatch_hw.h>

extern ow_control_block_t ow_control_block;

extern bool __flash_performMassErase();
extern bool __flash_programMemory(void* src, void* dest, uint32_t length);

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
  async command uint32_t OWhw.getResetStatus() {
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

    if (cur & OW_CS_DCORSHT_BIT)      gather |= RST_DCOSHORT;

    cur = CS->IFG;
    CS->CLRIFG = (CS_IFG_DCOR_OPNIFG | CS_IFG_DCOR_SHTIFG);

    if (cur & CS_IFG_DCOR_OPNIFG)     gather |= RST_DCOOPEN;
    if (cur & CS_IFG_DCOR_SHTIFG)     gather |= RST_DCOSHORT;

    return gather;
  }


  async command uint32_t OWhw.getResetOthers() {
    return others;
  }


  void launch(uint32_t base) {
    __asm__ volatile (
      "  ldr sp, [%0] \n"
      "  ldr pc, [%0, #4] \n" : : "r" (base) );
  }


  /*
   * returns FAIL if we can't launch
   */
  async command void OWhw.boot_image(image_info_t *iip) {
    if (iip->sig != IMAGE_INFO_SIG)
      return;
    launch(iip->image_start);
  }


  /*
   * fake_reset: debugging reset issues, don't reset
   *
   * Do basic reset functions
   *
   * force VTOR to 0
   * grab SP from 0
   * grab PC from 4
   */
  async command void OWhw.fake_reset() {
    __disable_irq();
    __DSB(); __ISB();
    SCB->VTOR = 0;
    __DSB(); __ISB();
    launch(0);
  }


  /*
   * getImageBase: return base address of executing image.
   *
   * We simply use the VTOR.  The vectors for msp432 based platforms
   * get placed at the beginning of the image which has to be
   * properly aligned for Vector tables.  (see hardware documentation
   * for SCB->VTOR restrictions.  (This gets enforced by the
   * linker).
   */
  async command uint32_t OWhw.getImageBase() {
    return SCB->VTOR;
  }


  /*
   * Flash interaction code
   */

  async command error_t OWhw.flashProtectAll() {
    FLCTL->BANK0_MAIN_WEPROT = 0xffffffff;
    FLCTL->BANK1_MAIN_WEPROT = 0xffffffff;
    return SUCCESS;
  }


  /*
   * given a buffer, figure out a flash sector mask for the
   * msp432.  We assume a sector is 4096 (12 bits).  The sector
   * is with respect to the start of the bank.
   *
   * o We only use bank 1, 128K starting at 0x0002000.
   * o the buffer must be inside of bank 1, inclusive.
   *
   * We mask off the upper 15 bits leaving the lower 17 bits.  12
   * bits make up the 4Ki.  leaving the upper 5 bits for sector
   * number.
   *
   * S_s is the sector number containing start.
   * S_t is the sector number containing start + len - 1
   *
   * The mask can be computed via:
   *
   * a   2 ** S_t        is a single bit representing the sector
   *                     containing S_t.
   *
   * b   (2 ** S_t) - 1  is a bit mask of all the sectors below
   *                     the tailing sector.
   *
   * c   (2 ** S_s) - 1  is a bit mask of all the sectors below
   *                     the starting sector.
   *
   *     (((2 ** S_t) - 1) & ~((2**S_s) - 1)) is all of the bits
   *                     below 2**S_t excluding all of the bits
   *                     below 2**S_s.
   *
   * sector mask is then:
   *
   *     2**S_t | (((2 ** S_t) - 1) & ~((2**S_s) - 1))
   *        a                b                 c
   *
   */
  uint32_t getSectorMask(uint8_t *start, uint32_t len) {
    uint32_t s_s, s_t, a_s, a_t;
    uint32_t sec_mask, a, b, c;

    a_s = (uint32_t) start;
    a_t = a_s + len - 1;

    if ((a_s < 0x00020000) || (a_t > 0x0003fffff))
      return 0;

    s_s = (a_s & 0x1ffff) >> 12;
    s_t = (a_t & 0x1ffff) >> 12;
    a = (1 << s_t);
    b = a - 1;
    c = (1 << s_s) - 1;
    sec_mask = a | (b & ~c);
    return sec_mask;
  }


  async command error_t OWhw.flashErase(uint8_t *fdest, uint32_t len) {
    uint32_t sec_mask;

    sec_mask = getSectorMask(fdest, len);
    if (!sec_mask)
      return SUCCESS;

    /* turn off write/erase protection for listed banks */
    FLCTL->BANK1_MAIN_WEPROT = ~sec_mask;
    if (__flash_performMassErase())
      return SUCCESS;
    return FAIL;
  }


  async command error_t OWhw.flashProgram(uint8_t *src, uint8_t *fdest,
                                    uint32_t len) {
    if (((uint32_t) fdest < 0x00020000) ||
        (((uint32_t) fdest  + len - 1) > 0x0003fffff))
      return FAIL;
    if (__flash_programMemory(src, fdest, len))
      return SUCCESS;
    return FAIL;
  }
}
