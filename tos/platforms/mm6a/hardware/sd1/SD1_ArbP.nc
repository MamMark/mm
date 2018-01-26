/*
 * Copyright 2017 Eric B. Decker
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

#ifndef SD1_RESOURCE
#define SD1_RESOURCE     "SD1.Resource"
#endif

configuration SD1_ArbP {
  provides {
    interface Resource[uint8_t id];
    interface ResourceRequested[uint8_t id];
  }
}
implementation {
  components new FcfsArbiterC(SD1_RESOURCE) as ArbiterC;
  Resource             = ArbiterC;
  ResourceRequested    = ArbiterC;

  components SD1C as SD;
  SD.ResourceDefaultOwner -> ArbiterC;
}
