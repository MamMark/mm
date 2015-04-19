/*
 * Copyright (c) 2012, 2015 Eric B. Decker
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
      P1OUT = 0x00;
      P1DIR = 0x03;

      /*
       * P3 has led2, gps_simo
       */
      P3OUT = 0x80;
      P3DIR = 0x10;

      /*
       * GPS: ORG4472, USCI B1, SPI
       *
       * For gps, P4.0 to P4.3 used.
       *
       * p4.0: on_off (output)
       * p4.1: resetn (output)
       * p4.2: csn    (output)
       * p4.3: awake  (input)
       */
      P4OUT = BIT2 | BIT1;		/* csn and resetn deasserted (1), on_off is 0. */
      P4DIR = BIT2 | BIT1 | BIT0;	/* 2, 1, 0 outputs */

      /*
       * TMP102/112, USCI B3, I2C
       *
       * P10.1: B3SDA
       * P10.2: B3SCL
       *
       * no initilization, leave alone.
       */

      /*
       * Accel, LIS331HH (breakout), erzatz LIS3DH.   USCI A3, SPI
       *
       * previous sensor (accel)
       *
       * P10.0: accel_sclk, A3SCLK
       * P10.4: accel_mosi, A3MOSI
       * P10.5: accel_miso, A3MISO
       * P10.7: accel_cs_n
       */
      P10OUT = 0x80;                    /* accel_csn 1 */
      P10DIR = 0x99;
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
