/*
 * Copyright (c) 2009-2010 People Power Company
 * All rights reserved.
 *
 * This open source code was developed with funding from People Power Company
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

/**
 * @author David Moss
 * @author Peter A. Bigot <pab@peoplepowerco.com>
 */

module PlatformPinsP {
  provides interface Init;
}

implementation {
  int i;

  command error_t Init.init() {
    uint8_t test;

    atomic {
      /*
       * for now, just leave it all as the reset state.
       *
       * For gps, P4.0 to P43 used.
       *
       * p4.0: on_off
       * p4.1: resetn
       * p4.2: csn
       * p4.3: wakeup
       *
       * 5438, all input, with OUT/IN left alone.
       */
      P4OUT = BIT2 | BIT1;		/* csn and resetn deasserted. */
      P4DIR = BIT2 | BIT1 | BIT0;	/* 2, 1, 0 outputs */

      P4OUT &= ~BIT1;			/* reset */
      P4OUT |=  BIT1;			/* unreset */
      test = P4IN & BIT3;
      P4OUT |= BIT0;
      P4OUT &= ~BIT0;
      test = P4IN & BIT3;
      P4OUT |= BIT0;
      P4OUT &= ~BIT0;
      test = P4IN & BIT3;
      
      P4OUT &= ~BIT1;			/* reset */
      P4OUT |=  BIT1;			/* unreset */
      test = P4IN & BIT3;
      P4OUT |= BIT0;
      P4OUT &= ~BIT0;
      test = P4IN & BIT3;
      P4OUT |= BIT0;
      P4OUT &= ~BIT0;
      test = P4IN & BIT3;
      
      P4OUT &= ~BIT1;			/* reset */
      P4OUT |=  BIT1;			/* unreset */

#if 0 /* Disabled: these specific setting sare defaults, but others might not be */
      PMAPPWD = PMAPPW;                         // Get write-access to port mapping regs
      P1MAP5 = PM_UCA0RXD;                      // Map UCA0RXD output to P1.5
      P1MAP6 = PM_UCA0TXD;                      // Map UCA0TXD output to P1.6
      PMAPPWD = 0;                              // Lock port mapping registers
#endif //

    }
    return SUCCESS;
  }
}
