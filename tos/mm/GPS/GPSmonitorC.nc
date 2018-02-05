/**
 * Copyright (c) 2017-2018 Eric B. Decker
 * All rights reserved
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

#include <TagnetTLV.h>

configuration GPSmonitorC {
  provides {
    interface TagnetAdapter<tagnet_gps_xyz_t> as InfoSensGpsXyz;
    interface TagnetAdapter<uint8_t>          as InfoSensGpsCmd;
  }
  uses {
    interface GPSState;
    interface GPSControl;
    interface GPSTransmit;
    interface GPSReceive;
  }
}

implementation {
  components GPSmonitorP;
  InfoSensGpsXyz = GPSmonitorP;
  InfoSensGpsCmd = GPSmonitorP;

  GPSState       = GPSmonitorP;
  GPSControl     = GPSmonitorP;
  GPSTransmit    = GPSmonitorP;
  GPSReceive     = GPSmonitorP;

  components new TimerMilliC() as MonTimer;
  GPSmonitorP.MonTimer -> MonTimer;

  components PanicC;
  GPSmonitorP.Panic -> PanicC;

  components CollectC;
  GPSmonitorP.CollectEvent -> CollectC;
  GPSmonitorP.Collect -> CollectC;
}
