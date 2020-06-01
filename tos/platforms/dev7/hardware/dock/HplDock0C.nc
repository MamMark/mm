/*
 * Copyright (c) 2020 Eric B. Decker
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

configuration HplDock0C {
  provides interface DockCommHardware as HW;
}
implementation {
  components Msp432UsciA3P     as UsciP;
  components Dock0HardwareP    as DockHwP;
  components HplMsp432PortIntP as PortInts;

  HW                 = DockHwP;
  DockHwP.Usci      -> UsciP;
  DockHwP.AttnIRQ   -> PortInts.Int[DC_ATTN_PORT_INT];

  components McuSleepC;
  PortInts.McuSleep -> McuSleepC;

  components PanicC, PlatformC;
  DockHwP.Panic     -> PanicC;
  DockHwP.Platform  -> PlatformC;

  PlatformC.PeripheralInit -> DockHwP;
}
