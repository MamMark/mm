/*
 * Copyright (c) 2015, 2017 Eric B. Decker
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

#include <RadioConfig.h>

configuration HplSi446xC {
  provides {
    interface Si446xInterface;

    interface SpiByte;
    interface FastSpiByte;
    interface SpiPacket;
    interface SpiBlock;

    interface Alarm<TRadio, uint16_t> as Alarm;
  }
}
implementation {
  components HplMsp432GpioC as GIO;
  components HplMsp432PortIntP as PortInts;
  components PanicC, PlatformC;

  components Si446xPinsP;
  components Si446xSpiConfigP as RadioConf;

  Si446xInterface = Si446xPinsP;
  Si446xPinsP.RadioNIRQ -> PortInts.Int[SI446X_IRQN_PORT_PIN];

  /* radio port */
  components Msp432UsciSpiB2C as RadioC;
  RadioC.SIMO               -> GIO.UCB2SIMOxPM;
  RadioC.SOMI               -> GIO.UCB2SOMIxPM;
  RadioC.CLK                -> GIO.UCB2CLKxPM;
  RadioC.Panic              -> PanicC;
  RadioC.Platform           -> PlatformC;
  PlatformC.PeripheralInit  -> RadioC;
  RadioC.Msp432UsciConfigure-> RadioConf;

  SpiByte                   = RadioC;
  FastSpiByte               = RadioC;
  SpiPacket                 = RadioC;
  SpiBlock                  = RadioC;

  components new Alarm32khz16C() as AlarmC;
  Alarm                     = AlarmC;
}
