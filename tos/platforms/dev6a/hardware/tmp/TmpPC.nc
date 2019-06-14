/*
 * Copyright (c) 2017, 2019 Eric B. Decker
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
 * On board tmp sensor, addr 0x48.
 *
 * The tmp driver provides a parameterized singleton interface.  Currently
 * the bus is not arbitrated because we power up the onboard tmp, read it
 * then the external sensor.  There is no sense powering the tmps down
 * and there is no reason not to read the sensor together.
 *
 * Care must be taken to read the sensors in a reasonable fashion to avoid
 * conflicts.  The bus is not arbitrated.
 *
 * The sensors are typically turned off and there is only one pwr
 * bit that controls power to all sensors on the bus.
 */

configuration TmpPC {
  provides interface SimpleSensor<uint16_t>;
}

implementation {
  enum {
    TMP_ADDR   = 0x48,
  };

  components HplTmpC;
  SimpleSensor = HplTmpC.SimpleSensor[TMP_ADDR];
}
