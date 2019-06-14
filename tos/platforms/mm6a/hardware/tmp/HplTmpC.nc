/*
 * Copyright 2017, 2019 Eric B. Decker
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

/*
 * SimpleSensor uses a parameterized interface that is a device address.
 */

configuration HplTmpC {
  provides {
    interface SimpleSensor<uint16_t>[uint8_t dev_addr];
  }
}
implementation {
  components Msp432UsciB3P, Msp432UsciI2CB3C;

  components new  TimerMilliC() as TmpTimer;
  components      TmpHardwareP  as THP;
  THP.Usci     -> Msp432UsciB3P;
  THP.Timer    -> TmpTimer;

  components PlatformC, PanicC;
  PlatformC.PeripheralInit  -> THP;
  Msp432UsciI2CB3C.Platform -> PlatformC;
  Msp432UsciI2CB3C.Panic    -> PanicC;

  components Tmp1x2P as TmpDvr;
  SimpleSensor        = TmpDvr;
  TmpDvr.I2CReg      -> Msp432UsciI2CB3C;
  TmpDvr.TmpHardware -> THP;
}
