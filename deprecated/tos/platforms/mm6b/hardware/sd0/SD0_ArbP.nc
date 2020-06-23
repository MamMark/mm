/*
 * Copyright 2016-2017 Eric B. Decker
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

#ifndef SD0_RESOURCE
#define SD0_RESOURCE     "SD0.Resource"
#endif

configuration SD0_ArbP {
  provides {
    interface Resource[uint8_t id];
    interface ResourceRequested[uint8_t id];
  }
}
implementation {
  components new FcfsArbiterC(SD0_RESOURCE) as ArbiterC;
  Resource             = ArbiterC;
  ResourceRequested    = ArbiterC;

  components SD0C as SD;
  SD.ResourceDefaultOwner -> ArbiterC;
}
