/*
 * Copyright (c) 2014, 2017 Eric B. Decker
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
 * @author Eric B. Decker <cire831@gmail.com>
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
  }
  uses {
    interface Init as PlatformPins;
    interface Init as PlatformLeds;
    interface Init as PlatformClock;
    interface Init as MoteInit;
    interface Init as PeripheralInit;
    interface Stack;
  }
}

implementation {

#ifdef notdef
  void uwait(uint16_t u) {
    uint16_t t0 = TA0R;
    while((TA0R - t0) <= u);
  }
#endif

  command error_t Init.init() {
    WDTCTL = WDTPW + WDTHOLD;           // Stop watchdog timer

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

    call PlatformPins.init();           // GPIO pins
    call PlatformLeds.init();           // Leds
    call PlatformClock.init();          // UCS, clock system
    call PeripheralInit.init();
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


  async command uint16_t BootParams.getBuild() {
    return _build;
  }


  /*
   * See PlatformClockP.nc for assignments
   */
  async command uint32_t Platform.usecsRaw()       { return TA1R; }
  async command uint32_t Platform.usecsRawSize()   { return 16; }
  async command uint32_t Platform.jiffiesRaw()     { return TA0R; }
  async command uint32_t Platform.jiffiesRawSize() { return 16; }

  /***************** Defaults ***************/
  default command error_t PeripheralInit.init() {
    return SUCCESS;
  }
}
