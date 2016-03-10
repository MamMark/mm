/*
 * Copyright 2010, 2012, 2016 (c) Eric B. Decker
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
 * Warning: many of these routines directly touch cpu registers
 * it is assumed that this is initilization code and interrupts are
 * off.
 *
 * @author Eric B. Decker
 */

#include "hardware.h"
#include "platform_version.h"


#ifdef notdef

#define STUFF_SIZE 32

noinit struct {
  uint8_t dcoctl;
  uint8_t bcsctl1;
  uint8_t bcsctl2;
  uint8_t bcsctl3;
} stuff[STUFF_SIZE];

noinit bool clear_stuff;
noinit uint16_t nxt;

void set_stuff() {
  if (clear_stuff) {
    memset(stuff, 0, sizeof(stuff));
    clear_stuff = 0;
    nxt = 0;
  }
  if (nxt >= STUFF_SIZE)
    nxt = 0;
  stuff[nxt].dcoctl  = DCOCTL;
  stuff[nxt].bcsctl1 = BCSCTL1;
  stuff[nxt].bcsctl2 = BCSCTL2;
  stuff[nxt].bcsctl3 = BCSCTL3;
  nxt++;
}

#endif


const uint8_t _major = MAJOR;
const uint8_t _minor = MINOR;
const uint8_t _build = _BUILD;


#define BOOT_MAJIK 0x01021910
noinit uint32_t boot_majik;
noinit uint16_t boot_count;
noinit uint16_t stack_size;


module PlatformP {
  provides {
    interface Init;
    interface BootParams;
    interface Platform;
    interface GeneralIO as Led0;
    interface GeneralIO as Led1;
    interface GeneralIO as Led2;
  }
  uses {
    interface Init as Msp430ClockInit;
    interface Init as LedsInit;
    interface Stack;
  }
}

implementation {

  /*
   * We assume that the clock system after reset has been
   * set to some reasonable value.  ie ~1MHz.  We assume that
   * all the selects are 0, ie.  DIVA/1, XTS 0, XT2OFF, SELM 0,
   * DIVM/1, SELS 0, DIVS/1.  MCLK <- DCO, SMCLK <- DCO,
   * LFXT1S 32768, XCAP ~6pf
   *
   * We wait about a second for the 32KHz to stablize.
   *
   * PWR_UP_SEC is the number of times we need to wait for
   * TimerA to cycle (16 bits) when clocked at the default
   * msp430f2618 dco (about 1 MHz).
   */

#define PWR_UP_SEC 16

  void wait_for_32K() __attribute__ ((noinline)) {
    uint16_t left;

    TACTL = TACLR;			// also zeros out control bits
    TBCTL = TBCLR;
    TACTL = TASSEL_2 | MC_2;		// SMCLK/1, continuous
    TBCTL = TBSSEL_1 | MC_2;		//  ACLK/1, continuous
    TBCCTL0 = 0;

    /*
     * wait for about a sec for the 32KHz to come up and
     * stabilize.  We are guessing that it is stable and
     * on frequency after about a second but this needs
     * to be verified.
     *
     * FIX ME.  Need to verify stability of 32KHz.  It definitely
     * has a good looking waveform but what about its frequency
     * stability.  Needs to be measured.
     */
    left = PWR_UP_SEC;
    while (1) {
      if (TACTL & TAIFG) {
	/*
	 * wrapped, clear IFG, and decrement major count
	 */
	TACTL &= ~TAIFG;
	if (--left == 0)
	  break;
      }
    }
  }


  command error_t Init.init() __attribute__ ((noinline)) {
    WDTCTL = WDTPW + WDTHOLD;
    TOSH_MM_INITIAL_PIN_STATE();

    /*
     * check to see if memory is okay.   The boot_majik cell tells the story.
     * If it isn't okay we lost RAM, reinitilize boot_count.
     */

    if (boot_majik != BOOT_MAJIK) {
      boot_majik = BOOT_MAJIK;
      boot_count = 0;
    }
    boot_count++;

    call Stack.init();
    stack_size = call Stack.size();

    /*
     * It takes a long time for the 32KHz Xtal to come up.
     * Go look to see when we start getting 32KHz ticks.
     * The routine waits for a second to give it time to
     * start up.
     */
    wait_for_32K();
    call Msp430ClockInit.init();
    call LedsInit.init();
    return SUCCESS;
  }


  async command uint16_t BootParams.getBootCount() {
    return boot_count;
  }


  async command uint8_t BootParams.getMajor() {
    return _major;
  }


  async command uint8_t BootParams.getMinor() {
    return _minor;
  }


  async command uint8_t BootParams.getBuild() {
    return _build;
  }


  async command void Led0.set() { };
  async command void Led0.clr() { };
  async command void Led0.toggle() { };
  async command bool Led0.get() { return 0; };
  async command void Led0.makeInput() { };
  async command bool Led0.isInput() { return FALSE; };
  async command void Led0.makeOutput() { };
  async command bool Led0.isOutput() { return FALSE; };  
  
  async command void Led1.set() { };
  async command void Led1.clr() { };
  async command void Led1.toggle() { };
  async command bool Led1.get() { return 0; };
  async command void Led1.makeInput() { };
  async command bool Led1.isInput() { return FALSE; };
  async command void Led1.makeOutput() { };
  async command bool Led1.isOutput() { return FALSE; };  
  
  async command void Led2.set() { };
  async command void Led2.clr() { };
  async command void Led2.toggle() { };
  async command bool Led2.get() { return 0; };
  async command void Led2.makeInput() { };
  async command bool Led2.isInput() { return FALSE; };
  async command void Led2.makeOutput() { };
  async command bool Led2.isOutput() { return FALSE; };  
  
  default command error_t LedsInit.init() { return SUCCESS; }

  /*
   * See PlatformClockP.nc for assignments
   */
  async command uint16_t Platform.usecsRaw()   { return TAR; }
  async command uint16_t Platform.jiffiesRaw() { return TBR; }
}
