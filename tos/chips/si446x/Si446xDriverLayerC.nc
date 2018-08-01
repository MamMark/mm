/*
 * Copyright (c) 2015, 2017, 2018 Eric B. Decker, Daniel J. Maltbie
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
 * Author: Eric B. Decker <cire831@gmail.com>
 *         December 2015.
 * Author: Daniel J. Maltbie <dmaltbie@daloma.org>
 *         May 2017.
 */

#include <RadioConfig.h>
#include <Si446xDriverLayer.h>

configuration Si446xDriverLayerC {
  provides {
    interface RadioState;
    interface RadioSend;
    interface RadioReceive;
    interface RadioCCA;
    interface RadioPacket;

    interface PacketField<uint8_t>  as PacketTransmitPower;
    interface PacketField<uint8_t>  as PacketRSSI;
    interface PacketField<uint16_t> as PacketTransmitDelay;

    interface Alarm<TRadio, tradio_size>;
  }
  uses {
    interface Si446xDriverConfig as Config;
    interface PacketTimeStamp<TRadio, uint32_t>;

    interface PacketFlag as TransmitPowerFlag;
    interface PacketFlag as TransmitDelayFlag;
    interface PacketFlag as RSSIFlag;
    interface RadioAlarm;
    interface Tasklet;
  }
}

implementation {
  components Si446xDriverLayerP as DriverLayerP;

  RadioState = DriverLayerP;
  RadioSend = DriverLayerP;
  RadioReceive = DriverLayerP;
  RadioCCA = DriverLayerP;
  RadioPacket = DriverLayerP;

  Config = DriverLayerP;

  PacketTransmitPower = DriverLayerP.PacketTransmitPower;
  DriverLayerP.TransmitPowerFlag = TransmitPowerFlag;

  PacketRSSI = DriverLayerP.PacketRSSI;
  DriverLayerP.RSSIFlag = RSSIFlag;

  PacketTransmitDelay = DriverLayerP.PacketTransmitDelay;
  DriverLayerP.TransmitDelayFlag = TransmitDelayFlag;

  PacketTimeStamp = DriverLayerP.PacketTimeStamp;

  components HplSi446xC;
  Alarm = HplSi446xC.Alarm;
  RadioAlarm = DriverLayerP.RadioAlarm;

  Tasklet = DriverLayerP.Tasklet;

  components Si446xCmdC;
  DriverLayerP.Si446xCmd         -> Si446xCmdC;

#ifdef RADIO_DEBUG_MESSAGES
  components DiagMsgC;
  DriverLayerP.DiagMsg -> DiagMsgC;
#endif

  components TraceC;
  DriverLayerP.Trace       -> TraceC;

#ifdef REQUIRE_PLATFORM
  components PlatformC;
  DriverLayerP.Platform    -> PlatformC;
#endif

#ifdef REQUIRE_PANIC
  components PanicC;
  DriverLayerP.Panic       -> PanicC;
#endif

  components new TimerMilliC()  as Timer0;
  DriverLayerP.sendTimer   -> Timer0;
}
