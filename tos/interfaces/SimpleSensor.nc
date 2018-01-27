/*
 * Copyright (c) 2017, Eric B. Decker
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
 * Read: read the value of the sensor.  The size is specified by val_t.
 *
 * isPresent returns true if the device is alive and functioning on the
 * bus.
 */

interface SimpleSensor<val_t> {
  command bool    isPresent();
  command error_t read();
  event   void    readDone(error_t result, val_t val);
}
