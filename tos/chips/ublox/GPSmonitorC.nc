/**
 * Copyright (c) 2017-2018, 2020 Eric B. Decker
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

/* Boot and Booted are the linkage into sequenced startup bootstrap. */
configuration GPSmonitorC {
  provides {
    interface TagnetAdapter<tagnet_gps_xyz_t> as InfoSensGpsXyz;
    interface TagnetAdapter<tagnet_gps_cmd_t> as InfoSensGpsCmd;
    interface GPSLog;
  }
  uses {
    interface GPSControl;
    interface MsgTransmit;
    interface MsgReceive;
    interface TagnetRadio;
  }
}

implementation {
  components SystemBootC, GPSmonitorP;
  GPSmonitorP.Boot   -> SystemBootC.Boot;

  InfoSensGpsXyz = GPSmonitorP;
  InfoSensGpsCmd = GPSmonitorP;
  GPSLog         = GPSmonitorP;

  GPSControl     = GPSmonitorP;
  MsgTransmit    = GPSmonitorP;
  MsgReceive     = GPSmonitorP;
  TagnetRadio    = GPSmonitorP;

  components McuSleepC;
  GPSmonitorP.McuPowerOverride <- McuSleepC;

  components new TimerMilliC() as MajorTimer;
  components new TimerMilliC() as TxTimer;
  GPSmonitorP.MajorTimer -> MajorTimer;
  GPSmonitorP.TxTimer    -> TxTimer;

  components PanicC;
  GPSmonitorP.Panic -> PanicC;

  components OverWatchC;
  GPSmonitorP.OverWatch -> OverWatchC;

  components CollectC;
  GPSmonitorP.CollectEvent -> CollectC;
  GPSmonitorP.Collect -> CollectC;

  components CoreTimeC;
  GPSmonitorP.CoreTime -> CoreTimeC;

  components PlatformC;
  GPSmonitorP.Rtc -> PlatformC;
}
