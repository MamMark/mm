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

configuration HplGPS0C {
  provides {
    interface Gsd4eUHardware;
    interface PwrReg as GPSPwr;
  }
}
implementation {
  components Msp432UsciA0P as UsciP;
  components GPS0HardwareP as GpsHwP;
  components PwrGpsMemsC;

  Gsd4eUHardware = GpsHwP;
  GPSPwr         = PwrGpsMemsC;
  GpsHwP.Usci      -> UsciP;
  GpsHwP.Interrupt -> UsciP;
  GpsHwP.PwrReg    -> PwrGpsMemsC;

  components PanicC, PlatformC;
  GpsHwP.Panic    -> PanicC;
  GpsHwP.Platform -> PlatformC;

  PlatformC.PeripheralInit -> GpsHwP;
}
