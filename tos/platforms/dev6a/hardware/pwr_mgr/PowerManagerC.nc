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

/*
 * PowerManager
 *
 * Manage various aspects of Power Management
 *
 * PowerManager.battery_connected: checks to see if the battery is
 *   connected.  Harvester interface.
 *
 * PowerManagerC.Boot: incoming boot.booted signal typically wired to
 *   MainC.Boot.booted.  Gets control when basic system initialization has
 *   completed..  Not SystemBoot.
 *
 * LowPowerBoot: not enough power to run all subsystems.  come up
 *               in low power mode.
 * OKPowerBoot:  power is ok, normal boot.  all subsystems should work.
 */

configuration PowerManagerC {
  provides {
    interface PowerManager;
    interface Boot as LowPowerBoot;     /* outgoing */
    interface Boot as OKPowerBoot;      /* outgoing */
  }
  uses {
    interface Boot;                     /* incoming */
  }
}
implementation {
  components PowerManagerP;
  PowerManager    = PowerManagerP;
  Boot            = PowerManagerP.Boot;
  LowPowerBoot    = PowerManagerP.LowPowerBoot;
  OKPowerBoot     = PowerManagerP.OKPowerBoot;

  components PlatformC, PanicC;
  PowerManagerP.Platform -> PlatformC;
  PowerManagerP.Panic    -> PanicC;
}
