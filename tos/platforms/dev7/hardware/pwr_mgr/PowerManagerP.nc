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
  /*
   * On the dev6a there isn't a harvester nor anyway to turn
   * power off to the tmp sensor bus.  Always on.
   *
   * o remember previous state,
   *     tmp_pwr_en
   *     Module state of tmp_scl and tmp_sda
   * o make tmp_scl an input
   * o turn tmp_pwr_en on
   * o check tmp_scl    if 1 -> battery is connect   (always should rtn 1)
   * o                  if 0 -> not connected.
   * o restore previous state.
   */
  async command bool PowerManager.battery_connected() {
    uint8_t  previous_pwr, previous_module;
    uint8_t  rtn;
    uint32_t t0;

    if (TMP_GET_SCL)
      return 1;

    rtn = 0;
    previous_pwr    = TMP_GET_PWR_STATE;
    previous_module = TMP_GET_SCL_MODULE_STATE;
    TMP_PINS_PORT;
    TMP_I2C_PWR_ON;
    t0 = call Platform.usecsRaw();
    while (1) {
      if (TMP_GET_SCL) {
        rtn = 1;
        break;
      }
      if (call Platform.usecsRaw() - t0 > 256)
        break;
    }
    if (previous_pwr == 0) TMP_I2C_PWR_OFF;
    if (previous_module)   TMP_PINS_MODULE;
    return rtn;
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
