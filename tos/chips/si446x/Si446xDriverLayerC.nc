/*
 * Copyright (c) 2015, 2017 Eric B. Decker
 * All rights reserved.
 *
 * Redistribution and use in source and binary forms, with or without
 * modification, are permitted provided that the following conditions
 * are met:
 *
 * - Redistributions of source code must retain the above copyright
 *   notice, this list of conditions and the following disclaimer.
 *
 * - Redistributions in binary form must reproduce the above copyright
 *   notice, this list of conditions and the following disclaimer in the
 *   documentation and/or other materials provided with the
 *   distribution.
 *
 * - Neither the name of the copyright holders nor the names of
 *   its contributors may be used to endorse or promote products derived
 *   from this software without specific prior written permission.
 *
 * THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS
 * "AS IS" AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT
 * LIMITED TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS
 * FOR A PARTICULAR PURPOSE ARE DISCLAIMED.  IN NO EVENT SHALL
 * THE COPYRIGHT HOLDER OR CONTRIBUTORS BE LIABLE FOR ANY DIRECT,
 * INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES
 * (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR
 * SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION)
 * HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT,
 * STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE)
 * ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED
 * OF THE POSSIBILITY OF SUCH DAMAGE.
 *
 * Author: Eric B. Decker <cire831@gmail.com>
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

    interface PacketField<uint8_t> as PacketTransmitPower;
    interface PacketField<uint8_t> as PacketRSSI;
    interface PacketField<uint8_t> as PacketTimeSyncOffset;
    interface PacketField<uint8_t> as PacketLinkQuality;
    //interface PacketField<uint8_t> as AckReceived;

    interface Alarm<TRadio, tradio_size>;
    interface PacketAcknowledgements;
  }
  uses {
    interface Si446xDriverConfig as Config;
    interface PacketTimeStamp<TRadio, uint32_t>;

    interface PacketFlag as TransmitPowerFlag;
    interface PacketFlag as RSSIFlag;
    interface PacketFlag as TimeSyncFlag;
    interface PacketFlag as AckReceivedFlag;
    interface RadioAlarm;
    interface Tasklet;
  }
}

implementation {
  components Si446xDriverLayerP as DriverLayerP,
	     MainC,
             HplSi446xC as HWHplC;

  MainC.SoftwareInit -> DriverLayerP.SoftwareInit;

  RadioState = DriverLayerP;
  RadioSend = DriverLayerP;
  RadioReceive = DriverLayerP;
  RadioCCA = DriverLayerP;
  RadioPacket = DriverLayerP;
  PacketAcknowledgements = DriverLayerP;

  Config = DriverLayerP;

  PacketTransmitPower = DriverLayerP.PacketTransmitPower;
  DriverLayerP.TransmitPowerFlag = TransmitPowerFlag;

  PacketRSSI = DriverLayerP.PacketRSSI;
  DriverLayerP.RSSIFlag = RSSIFlag;

  PacketTimeSyncOffset = DriverLayerP.PacketTimeSyncOffset;
  DriverLayerP.TimeSyncFlag = TimeSyncFlag;

  AckReceivedFlag = DriverLayerP.AckReceivedFlag;

  PacketLinkQuality = DriverLayerP.PacketLinkQuality;
  PacketTimeStamp = DriverLayerP.PacketTimeStamp;

  RadioAlarm = DriverLayerP.RadioAlarm;
  Alarm = HWHplC.Alarm;

  DriverLayerP.SpiResource -> HWHplC.SpiResource;
  DriverLayerP.FastSpiByte -> HWHplC;
  DriverLayerP.SpiByte     -> HWHplC;
  DriverLayerP.SpiBlock    -> HWHplC;

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
}
