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
 */

/**
 * @author Eric B. Decker <cire831@gmail.com>
 *
 * given a set of chips on an SPI bus, collect the chipselects and
 * the actual USCI h/w.  Expose as SpiReg[mem_id].
 */

configuration HplMems0C {
  provides interface SpiReg[uint8_t mem_id];
}
implementation {
  components HplMsp432GpioC   as GIO;
  components Msp432UsciSpiB1C as SpiC;
  components Mems0PinsP;
  components PanicC, PlatformC;

  SpiC.CLK                 -> GIO.UCB1CLK;
  SpiC.SOMI                -> GIO.UCB1SOMI;
  SpiC.SIMO                -> GIO.UCB1SIMO;
  SpiC.Panic               -> PanicC;
  SpiC.Platform            -> PlatformC;
  SpiC.Msp432UsciConfigure -> Mems0PinsP;

  PlatformC.PeripheralInit -> SpiC;

  components new MemsBusP() as MemsDvr;
  MemsDvr.FastSpiByte      -> SpiC;
  MemsDvr.SpiBus           -> Mems0PinsP;
  Mems0PinsP.Panic         -> PanicC;

  SpiReg = MemsDvr;

  PlatformC.PeripheralInit -> SpiC;
}
