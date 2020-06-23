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

bool pm_do_low_power;

module PowerManagerP {
  provides {
    interface PowerManager;
    interface Boot as LowPowerBoot;     /* outgoing */
    interface Boot as OKPowerBoot;      /* outgoing */
  }
  uses {
    interface Boot;
    interface Platform;
    interface Panic;
  }
}
implementation {
  async command bool PowerManager.battery_connected() {
    if (pm_do_low_power)
      return FALSE;
    return TRUE;
  }


  /*
   * Gets signalled on Main boot.  check to see what power
   * mode we are in currently.  If low power then signal
   * LowPowerBoot.  Otherwise signal OKPowerBoot.
   */
  event void Boot.booted() {
    if (call PowerManager.battery_connected())
      signal OKPowerBoot.booted();
    else
      signal LowPowerBoot.booted();
    return;
  }

  default event void LowPowerBoot.booted() {
    call Panic.panic(PANIC_PWR, 1, 0, 0, 0, 0);
  }

  async event void Panic.hook() { }
}
