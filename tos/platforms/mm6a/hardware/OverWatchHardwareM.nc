/*
 * Copyright (c) 2017-2018 Eric B. Decker
 * All rights reserved.
 *
 * This program is free software: you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation, either version 3 of the License, or
 * any later version.
 *
 * This program is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU General Public License for more details.
 *
 * You should have received a copy of the GNU General Public License
 * along with this program.  If not, see <https://www.gnu.org/licenses/>.
 * See COPYING in the top level directory of this source tree.
 *
 * Contact: Eric B. Decker <cire831@gmail.com>
 */

#include <overwatch.h>
#include <overwatch_hw.h>

norace extern ow_control_block_t ow_control_block;

extern bool __flash_performMassErase();
extern bool __flash_programMemory(void* src, void* dest, uint32_t length);
extern void __soft_reset();

module OverWatchHardwareM {
  provides interface OverWatchHardware as OWhw;
  uses     interface SysReboot;
}
implementation {

  norace uint32_t others;

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


  async command uint32_t OWhw.curFaults() {
    uint32_t faults = 0;
    uint32_t cs_int;

    cs_int = CS->IFG;
    if (cs_int &  CS_IFG_LFXTIFG)
      faults |= OW_FAULT_32K;
    if (cs_int & (CS_IFG_DCOR_SHTIFG | CS_IFG_DCOR_OPNIFG))
      faults |= OW_FAULT_DCOR;
    return faults;
  }


  async command uint32_t OWhw.getProtStatus() {
    return SYSCTL_Boot->SYSTEM_STAT;
  }


  void launch(uint32_t base) {
    __asm__ volatile (
      "  ldr sp, [%0] \n"
      "  ldr lr, [%0, #4] \n"
      "  bx  lr \n" : : "r" (base) );
  }


  async command void OWhw.boot_image(image_info_t *iip) {
    if (iip->iib.ii_sig != IMAGE_INFO_SIG)
      return;
    launch(iip->iib.image_start);
  }


  /*
   * soft_reset: software controlled reset/reboot
   */
  async command void OWhw.soft_reset() {
    /*
     * force a soft reset.  This will reset the core and core peripherals.
     * It will leave the I/O pin configuration alone.  Non-core peripherals
     * will need to be reset by software.
     */
    call SysReboot.soft_reboot(SYSREBOOT_OW_REQUEST);
    call OWhw.fake_reset();
  }


  /*
   * hard_reset: full on hard reset
   */
  async command void OWhw.hard_reset() {
    call SysReboot.reboot(SYSREBOOT_OW_REQUEST);
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
   * flush: tell reboot code to signal a flush
   */
  async command void OWhw.flush() {
    call SysReboot.flush();
  }


  /*
   * halt: power down and stop
   */
  async command void OWhw.halt_and_CF() {
    __disable_irq();
    call SysReboot.flush();
    __soft_reset();

    P1->OUT = 0x60; P1->DIR = 0x6C;
    P2->OUT = 0x89; P2->DIR = 0xC9;
    P2->SEL0= 0x10; P2->SEL1= 0x00;
    P3->OUT = 0x7B; P3->DIR = 0x7B;
    P3->SEL0= 0x01; P3->SEL1= 0x00;
    P4->OUT = 0x30; P4->DIR = 0xFD;
    P5->OUT = 0x81; P5->DIR = 0xA7;
    P6->OUT = 0x08; P6->DIR = 0x18;
    P6->SEL0= 0x38; P6->SEL1= 0x00;
    P7->OUT = 0xB9; P7->DIR = 0xF8;
    P7->SEL0= 0x80; P7->SEL1= 0x00;
    P8->OUT = 0x00; P8->DIR = 0x02;
    PJ->OUT = 0x04; PJ->DIR = 0x02;
    P7->REN = 0x01;

    /*
     * we can put the main cpu into LPM3.5 if needed.
     * but let's see what LPM0 does with all our other pwr off.
     */
    __asm volatile ("wfe");
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
   * o bank parameter indicates which bank we are messing with.
   * o bank 0 is 0x0000_0000 to 0x0001_FFFF (128K)
   * o        only upper 8K is allowed.
   * o bank 1 is 0x0002_0000 to 0x0003_FFFF (128K)
   *          all of bank 1 is allowed.
   * o buffer must be wholly inside the bank.
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
   * returns 0 if any of our checks fail.
   */
  uint32_t getSectorMask(uint32_t bank, uint8_t *start, uint32_t len) {
    uint32_t s_s, s_t, a_s, a_t;
    uint32_t sec_mask, a, b, c;

    a_s = (uint32_t) start;
    a_t = a_s + len - 1;

    switch (bank) {
      default:
        return 0;

      case 0:
        /* only allow upper 8K of bank 0 */
        if (a_s < (0x00020000 - (8 * 1024)) || a_s >= 0x00020000)
          return 0;
        if (a_t >= 0x00020000)
          return 0;
        break;

      case 1:
        if ((a_s < 0x00020000) || (a_t >= 0x00040000))
          return 0;
        break;
    }

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
    uint32_t *chk, *limit;
    uint32_t bank;

    bank = 1;
    if ((uint32_t) fdest < 0x00020000)
      bank = 0;
    sec_mask = getSectorMask(bank, fdest, len);
    if (!sec_mask)
      return FAIL;

    /* turn off write/erase protection for listed banks */
    if (bank == 0)
      FLCTL->BANK0_MAIN_WEPROT = ~sec_mask;
    else
      FLCTL->BANK1_MAIN_WEPROT = ~sec_mask;
    if (__flash_performMassErase()) {
      chk   = (uint32_t *) fdest;
      limit = (uint32_t *) ((uint32_t) (fdest + len) & ~3);
      while (chk < limit) {
        if (*chk++ != 0xFFFFFFFF) {
          ROM_DEBUG_BREAK(0x10);
          return FAIL;
        }
      }
      return SUCCESS;
    }
    return FAIL;
  }


  async command error_t OWhw.flashProgram(uint8_t *src, uint8_t *fdest,
                                    uint32_t len) {
    uint32_t *chk, *s, *limit;

    if (((uint32_t) fdest < 0x0001E000) ||
        (((uint32_t) fdest  + len) >= 0x00040000))
      return FAIL;
    if (__flash_programMemory(src, fdest, len)) {
      s     = (uint32_t *) src;
      chk   = (uint32_t *) fdest;
      limit = (uint32_t *) ((uint32_t) (fdest + len) & ~3);
      while (chk < limit) {
        if (*chk++ != *s++) {
          ROM_DEBUG_BREAK(0x10);
          return FAIL;
        }
      }
      return SUCCESS;
    }
    return FAIL;
  }

  async event void SysReboot.shutdown_flush() { }
}
