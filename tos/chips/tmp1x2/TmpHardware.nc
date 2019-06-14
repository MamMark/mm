/*
 * Copyright (c) 2019, Eric B. Decker
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
 * Defines the interface to underlying tmp sensor hardware.
 *
 * When the tmp bus is powered down, we need to make sure that no pins
 * wired to the SD are driven high as this can cause the card to power
 * up via those pins (because of the input clamping diodes).
 *
 *  tmp_pwr_on:         turn on power to requested tmp sensor.
 *  tmp_pwr_off:        turn off power to requested tmp sensor.
 *  isTmpPowered:       returns true if particular TMP bus is powered.
 *
 * @author Eric B. Decker <cire831@gmail.com>
 */

interface TmpHardware {
  command error_t tmp_on(uint8_t dev_addr);
  event   void    tmp_on_done(error_t error, uint8_t dev_addr);

  command error_t tmp_off(uint8_t dev_addr);
  event   void    tmp_off_done(error_t error, uint8_t dev_addr);

  command bool isTmpPowered(uint8_t dev_addr);
}
