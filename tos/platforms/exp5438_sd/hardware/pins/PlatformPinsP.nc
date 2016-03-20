/*
 * Copyright (c) 2012, 2016 Eric B. Decker
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
       * P3.7: usd_simo
       */
      P1OUT = 0;
      P1DIR = 0x3;

      P3OUT = 0;
      P3DIR = 0x90;

      /* usd_csn, P4.2, low true, deassert */
      P4OUT = 0x04;
      P4DIR = 0x04;

      /* usd_somi, usd_sclk */
      P5OUT = 0;
      P5DIR = 0x20;

      /*
       * Radio, siLabs 4463 module   USCI A3, SPI
       *
       * P10.0: si446x_sclk, A3SCLK
       * P10.4: si446x_mosi, A3MOSI
       * P10.5: si446x_miso, A3MISO
       * P10.6: si446x_sdn (shutdown)
       * P10.7: si446x_csn
       */
      P10OUT = 0xc0;                    /* sdn = 1, csn = 1 (deasserted) */
      P10DIR = 0xd9;
    }
    return SUCCESS;
  }
}
