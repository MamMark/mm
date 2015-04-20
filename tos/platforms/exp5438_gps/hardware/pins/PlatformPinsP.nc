/*
 * Copyright (c) 2012 Eric B. Decker
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

module PlatformPinsP {
  provides interface Init;
}

implementation {
  command error_t Init.init() {

    atomic {
      /*
       * Main default pin setting is all input after reset
       * except for the follow exceptions where we have hardware
       * hooked up.
       */

      /*
       * Port 1: leds
       * Port 3: led
       */
      P1OUT = 0;
      P1DIR = 0x3;
      P3OUT = 0;
      P3DIR = 0x10;

      /*
       * GPS: ORG4472, USCI B1, SPI
       *
       * For gps, P4.0 to P4.3 used.
       *
       * p4.0: on_off
       * p4.1: resetn
       * p4.2: csn
       * p4.3: awake
       */
      P4OUT = BIT2 | BIT1;		/* csn and resetn deasserted (1), on_off is 0. */
      P4DIR = BIT2 | BIT1 | BIT0;	/* 2, 1, 0 outputs */

      /*
       * Radio, siLabs 4463 module   USCI A3, SPI
       *
       * P10.0: r446x_sclk, A3SCLK
       * P10.4: r446x_mosi, A3MOSI
       * P10.5: r446x_miso, A3MISO
       * P10.6: r446x_sdn (shutdown)
       * P10.7: r446x_csn
       */
      P10OUT = 0xc0;                    /* sdn = 1, csn = 1 (deasserted) */
      P10DIR = 0xc9;
    }

#if 0 /* Disabled: these specific setting sare defaults, but others might not be */
      PMAPPWD = PMAPPW;                         // Get write-access to port mapping regs
      P1MAP5 = PM_UCA0RXD;                      // Map UCA0RXD output to P1.5
      P1MAP6 = PM_UCA0TXD;                      // Map UCA0TXD output to P1.6
      PMAPPWD = 0;                              // Lock port mapping registers
#endif //
    return SUCCESS;
  }
}
