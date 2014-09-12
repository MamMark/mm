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
 */

#include "msp430usci.h"

/**
 * Connect the appropriate pins for USCI support on a msp430f5438a (also
 * works for 5438)
 *
 * @author Eric B. Decker <cire831@gmail.com>
 */

configuration PlatformUsciMapC {
} implementation {
  components HplMsp430GeneralIOC as GIO;

  components Msp430UsciUartA0P as UartA0;
  UartA0.URXD -> GIO.UCA0RXD;
  UartA0.UTXD -> GIO.UCA0TXD;

  components Msp430UsciSpiA3P as SpiA3;
  SpiA3.SIMO -> GIO.UCA3SIMO;
  SpiA3.SOMI -> GIO.UCA3SOMI;
  SpiA3.CLK  -> GIO.UCA3CLK;

  components Msp430UsciSpiB0P as SpiB0;
  SpiB0.SIMO -> GIO.UCB0SIMO;
  SpiB0.SOMI -> GIO.UCB0SOMI;
  SpiB0.CLK  -> GIO.UCB0CLK;

  components Msp430UsciSpiB1P as SpiB1;
  SpiB1.SIMO -> GIO.UCB1SIMO;
  SpiB1.SOMI -> GIO.UCB1SOMI;
  SpiB1.CLK  -> GIO.UCB1CLK;

  components Msp430UsciI2CB3P as I2CB3;
  I2CB3.SDA -> GIO.UCB3SDA;
  I2CB3.SCL -> GIO.UCB3SCL;
}
