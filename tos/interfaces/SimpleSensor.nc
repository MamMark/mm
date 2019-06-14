/*
 * Copyright (c) 2017, 2019, Eric B. Decker
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
 * SimpleSensor provides:
 *
 * isPwrOn: returns TRUE if sensor power is on, FALSE otherwise.
 *
 * pwrUp: power up the sensor, returns EALREADY if sensor power is already
 * on and stable.  SUCCESS if split phase is needed.
 *
 * pwrDown: power down the sensor, returns EOFF if sensor is powered
 * down.  SUCCESS if split phase is needed.
 *
 * Read: read the value of the sensor.  The size is specified by val_t.
 * if the sensor is powered off, EOFF, otherwise SUCCESS is returned.
 *
 * isPresent returns TRUE if the device is alive and functioning on the
 * bus.  Must be powered up first.  Otherwise always return FALSE.
 */

interface SimpleSensor<val_t> {
  command bool    isPwrOn();

  command error_t pwrUp();
  event   void    pwrUpDone(error_t result);

  command error_t pwrDown();
  event   void    pwrDownDone(error_t result);

  command bool    isPresent();

  command error_t read(val_t *valptr);
}
