/*
 * Copyright (c) 2017 Eric B. Decker
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
  components Msp432UsciSpiA1C as SpiC;
  components Mems0PinsP;
  components PanicC, PlatformC;

  SpiC.CLK                 -> GIO.Port70;
  SpiC.SOMI                -> GIO.Port71;
  SpiC.SIMO                -> GIO.Port72;
  SpiC.Panic               -> PanicC;
  SpiC.Platform            -> PlatformC;
  SpiC.Msp432UsciConfigure -> Mems0PinsP;

  PlatformC.PeripheralInit -> SpiC;

  components new MemsBusP() as MemsDvr;
  MemsDvr.FastSpiByte      -> SpiC;
  MemsDvr.SpiBus           -> Mems0PinsP;
  Mems0PinsP.Panic         -> PanicC;

  SpiReg = MemsDvr;
}
