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
 * Top level of the Tmp Port
 *
 * The tmp driver provides a parameterized singleton interface.  There
 * is a single driver that handles all of the temperature sensors.  The
 * parameter is the device address of the sensor.  ie.  0x48 for
 * TmpP and 0x49 for TmpX.  The address depends on how the tmp1x2 is
 * physically wired.
 *
 * The driver uses the dev_addr to address the sensor on the I2C bus and
 * uses a mapping between dev_addr and an appropriate client id (cid)
 * for accessing the resource.  Both dev_addrs and cids are unique.
 *
 * Access to the bus and power to the sensors is controlled by the
 * arbiter's ResourceDefaultOwner.
 *
 * The sensors are typically turned off and there is only one pwr
 * bit that controls power to all sensors on the bus.  This power
 * bit is controlled by the ResourceDefaultOwner wired into the
 * arbiter.  Power will be turned on as long as there is at least
 * one client using the bus.
 */

configuration TmpPC {
  provides interface SimpleSensor<uint16_t>;
  provides interface Resource;
}

implementation {

  enum {
    TMP_CLIENT = 0,
    TMP_ADDR   = 0x48,
  };

  components HplTmpC;
  SimpleSensor = HplTmpC.SimpleSensor[TMP_ADDR];
  Resource     = HplTmpC.Resource[TMP_CLIENT];
}
