/*
 * Copyright (c) 2015, 2018  Eric B. Decker, Daniel J. Maltbie
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
 * Author: Daniel J. Maltbie <dmaltbie>
 */

#include <RadioConfig.h>

configuration Si446xRadioC {
  provides {
    interface SplitControl;

#ifndef IEEE154FRAMES_ENABLED
    interface AMSend[am_id_t id];
    interface Receive[am_id_t id];
    interface Receive as Snoop[am_id_t id];
    interface SendNotifier[am_id_t id];
    interface AMPacket;
    interface Packet as PacketForActiveMessage;
#endif

#ifndef TFRAMES_ENABLED
    interface Ieee154Send;
    interface Receive as Ieee154Receive;
    interface SendNotifier as Ieee154Notifier;

    interface Resource as SendResource[uint8_t clint];

    interface Ieee154Packet;
    interface Packet as PacketForIeee154Message;
#endif

    interface PacketAcknowledgements;
    interface LowPowerListening;
    interface PacketLink;

#ifdef TRAFFIC_MONITOR
    interface TrafficMonitor;
#endif

    interface RadioChannel;

    interface PacketField<uint16_t> as PacketTransmitDelay;
    interface PacketField<uint8_t> as PacketTransmitPower;
    interface PacketField<uint8_t> as PacketRSSI;

    interface LocalTime<TRadio> as LocalTimeRadio;
    interface PacketTimeStamp<TRadio, uint32_t> as PacketTimeStampRadio;
    interface PacketTimeStamp<TMilli, uint32_t> as PacketTimeStampMilli;
  }
}

implementation {

#define UQ_METADATA_FLAGS "UQ_SI446X_METADATA_FLAGS"
#define UQ_RADIO_ALARM    "UQ_SI446X_RADIO_ALARM"

  components new TaskletC();
  components new RadioAlarmC();
  components Si446xRadioP as RadioP;
  components Si446xDriverLayerC as RadioDriverLayerC;

#ifdef RADIO_DEBUG
  components AssertC;
#endif

  RadioP.Ieee154PacketLayer -> Ieee154PacketLayerC;
  RadioP.RadioAlarm -> RadioAlarmC.RadioAlarm[unique(UQ_RADIO_ALARM)];
  RadioP.PacketTimeStamp -> TimeStampingLayerC;
  RadioP.Si446xPacket -> RadioDriverLayerC;

  RadioAlarmC.Alarm -> RadioDriverLayerC;
  RadioAlarmC.Tasklet -> TaskletC;

// -------- Active Message

#ifndef IEEE154FRAMES_ENABLED
  components new ActiveMessageLayerC();
  ActiveMessageLayerC.Config -> RadioP;
  ActiveMessageLayerC.SubSend -> AutoResourceAcquireLayerC;
  ActiveMessageLayerC.SubReceive -> TinyosNetworkLayerC.TinyosReceive;
  ActiveMessageLayerC.SubPacket -> TinyosNetworkLayerC.TinyosPacket;

  AMSend = ActiveMessageLayerC;
  Receive = ActiveMessageLayerC.Receive;
  Snoop = ActiveMessageLayerC.Snoop;
  SendNotifier = ActiveMessageLayerC;
  AMPacket = ActiveMessageLayerC;
  PacketForActiveMessage = ActiveMessageLayerC;
#endif

// -------- Automatic RadioSend Resource

#ifndef IEEE154FRAMES_ENABLED
#ifndef TFRAMES_ENABLED
  components new AutoResourceAcquireLayerC();
  AutoResourceAcquireLayerC.Resource -> SendResourceC.Resource[unique(RADIO_SEND_RESOURCE)];
#else
  components new DummyLayerC() as AutoResourceAcquireLayerC;
#endif
  AutoResourceAcquireLayerC -> TinyosNetworkLayerC.TinyosSend;
#endif

// -------- RadioSend Resource

#ifndef TFRAMES_ENABLED
  components new SimpleFcfsArbiterC(RADIO_SEND_RESOURCE) as SendResourceC;
  SendResource = SendResourceC;

// -------- Ieee154 Message

  components new Ieee154MessageLayerC();
  Ieee154MessageLayerC.Ieee154PacketLayer -> Ieee154PacketLayerC;
  Ieee154MessageLayerC.SubSend -> TinyosNetworkLayerC.Ieee154Send;
  Ieee154MessageLayerC.SubReceive -> TinyosNetworkLayerC.Ieee154Receive;
  Ieee154MessageLayerC.RadioPacket -> TinyosNetworkLayerC.Ieee154Packet;

  Ieee154Send = Ieee154MessageLayerC;
  Ieee154Receive = Ieee154MessageLayerC;
  Ieee154Notifier = Ieee154MessageLayerC;
  Ieee154Packet = Ieee154PacketLayerC;
  PacketForIeee154Message = Ieee154MessageLayerC;
#endif

// -------- Tinyos Network

  components new TinyosNetworkLayerC();

  TinyosNetworkLayerC.SubSend -> UniqueLayerC;
  TinyosNetworkLayerC.SubReceive -> PacketLinkLayerC;
  TinyosNetworkLayerC.SubPacket -> Ieee154PacketLayerC;

// -------- IEEE 802.15.4 Packet

  components new Ieee154PacketLayerC();
  Ieee154PacketLayerC.SubPacket -> PacketLinkLayerC;

// -------- UniqueLayer Send part (wired twice)

  components new UniqueLayerC();
  UniqueLayerC.Config -> RadioP;
  UniqueLayerC.SubSend -> PacketLinkLayerC;

// -------- Packet Link

  components new PacketLinkLayerC();
  PacketLink = PacketLinkLayerC;
#ifdef SI446X_HARDWARE_ACK
  PacketLinkLayerC.PacketAcknowledgements -> RadioDriverLayerC;
#else
  PacketLinkLayerC.PacketAcknowledgements -> SoftwareAckLayerC;
#endif
  PacketLinkLayerC -> LowPowerListeningLayerC.Send;
  PacketLinkLayerC -> LowPowerListeningLayerC.Receive;
  PacketLinkLayerC -> LowPowerListeningLayerC.RadioPacket;

// -------- MessageBuffer

  components new MessageBufferLayerC();
  MessageBufferLayerC.RadioSend -> CollisionAvoidanceLayerC;
  MessageBufferLayerC.RadioReceive -> UniqueLayerC;
  MessageBufferLayerC.RadioState -> TrafficMonitorLayerC;
  MessageBufferLayerC.Tasklet -> TaskletC;
  RadioChannel = MessageBufferLayerC;

// -------- Low Power Listening

#ifdef LOW_POWER_LISTENING
#warning "*** USING LOW POWER LISTENING LAYER"
  components new LowPowerListeningLayerC();
  LowPowerListeningLayerC.Config -> RadioP;
#ifdef SI446X_HARDWARE_ACK
  LowPowerListeningLayerC.PacketAcknowledgements -> RadioDriverLayerC;
#else
  LowPowerListeningLayerC.PacketAcknowledgements -> SoftwareAckLayerC;
#endif
#else
  components new LowPowerListeningDummyC() as LowPowerListeningLayerC;
#endif
  LowPowerListeningLayerC.SubControl -> MessageBufferLayerC;
  LowPowerListeningLayerC.SubSend -> MessageBufferLayerC;
  LowPowerListeningLayerC.SubReceive -> MessageBufferLayerC;
  LowPowerListeningLayerC.SubPacket -> TimeStampingLayerC;
  SplitControl = LowPowerListeningLayerC;
  LowPowerListening = LowPowerListeningLayerC;

// -------- UniqueLayer receive part (wired twice)

  UniqueLayerC.SubReceive -> CollisionAvoidanceLayerC;

// -------- CollisionAvoidance

#ifdef SLOTTED_MAC
  components new SlottedCollisionLayerC() as CollisionAvoidanceLayerC;
#else
  components new RandomCollisionLayerC() as CollisionAvoidanceLayerC;
#endif
  CollisionAvoidanceLayerC.Config -> RadioP;
  CollisionAvoidanceLayerC.SubSend -> SoftwareAckLayerC;
  CollisionAvoidanceLayerC.SubReceive -> SoftwareAckLayerC;
  CollisionAvoidanceLayerC.RadioAlarm -> RadioAlarmC.RadioAlarm[unique(UQ_RADIO_ALARM)];

// -------- SoftwareAcknowledgement

#ifndef SI446X_HARDWARE_ACK
  components new SoftwareAckLayerC();
  SoftwareAckLayerC.AckReceivedFlag -> MetadataFlagsLayerC.PacketFlag[unique(UQ_METADATA_FLAGS)];
  SoftwareAckLayerC.RadioAlarm -> RadioAlarmC.RadioAlarm[unique(UQ_RADIO_ALARM)];
  PacketAcknowledgements = SoftwareAckLayerC;
#else
  components new DummyLayerC() as SoftwareAckLayerC;
#endif
  SoftwareAckLayerC.Config -> RadioP;
  SoftwareAckLayerC.SubSend -> CsmaLayerC;
  SoftwareAckLayerC.SubReceive -> CsmaLayerC;

// -------- Carrier Sense

  components new DummyLayerC() as CsmaLayerC;
  CsmaLayerC.Config -> RadioP;
  CsmaLayerC -> TrafficMonitorLayerC.RadioSend;
  CsmaLayerC -> TrafficMonitorLayerC.RadioReceive;
  CsmaLayerC -> RadioDriverLayerC.RadioCCA;

// -------- TimeStamping

  components new TimeStampingLayerC();
  TimeStampingLayerC.LocalTimeRadio -> RadioDriverLayerC;
  TimeStampingLayerC.SubPacket -> MetadataFlagsLayerC;
  PacketTimeStampRadio = TimeStampingLayerC;
  PacketTimeStampMilli = TimeStampingLayerC;
  TimeStampingLayerC.TimeStampFlag -> MetadataFlagsLayerC.PacketFlag[unique(UQ_METADATA_FLAGS)];

// -------- MetadataFlags

  components new MetadataFlagsLayerC();
  MetadataFlagsLayerC.SubPacket -> RadioDriverLayerC;

// -------- Traffic Monitor

#ifdef TRAFFIC_MONITOR
  components new TrafficMonitorLayerC();
  TrafficMonitor = TrafficMonitorLayerC;
#else
  components new DummyLayerC() as TrafficMonitorLayerC;
#endif
  TrafficMonitorLayerC.Config -> RadioP;
  TrafficMonitorLayerC -> RadioDriverLayerC.RadioSend;
  TrafficMonitorLayerC -> RadioDriverLayerC.RadioReceive;
  TrafficMonitorLayerC -> RadioDriverLayerC.RadioState;

// -------- Driver

  RadioDriverLayerC.Config -> RadioP;
  RadioDriverLayerC.PacketTimeStamp -> TimeStampingLayerC;
  PacketTransmitPower = RadioDriverLayerC.PacketTransmitPower;
  PacketTransmitDelay = RadioDriverLayerC.PacketTransmitDelay;
  PacketRSSI = RadioDriverLayerC.PacketRSSI;
  LocalTimeRadio = RadioDriverLayerC;

  RadioDriverLayerC.TransmitPowerFlag -> MetadataFlagsLayerC.PacketFlag[unique(UQ_METADATA_FLAGS)];
  RadioDriverLayerC.TransmitDelayFlag -> MetadataFlagsLayerC.PacketFlag[unique(UQ_METADATA_FLAGS)];
  RadioDriverLayerC.RSSIFlag -> MetadataFlagsLayerC.PacketFlag[unique(UQ_METADATA_FLAGS)];
  RadioDriverLayerC.TimeSyncFlag -> MetadataFlagsLayerC.PacketFlag[unique(UQ_METADATA_FLAGS)];

  RadioDriverLayerC.RadioAlarm -> RadioAlarmC.RadioAlarm[unique(UQ_RADIO_ALARM)];
  RadioDriverLayerC.Tasklet -> TaskletC;
}
