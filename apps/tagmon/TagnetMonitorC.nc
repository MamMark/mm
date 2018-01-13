/*
 * Copyright (c) 2015 Eric B. Decker
 * Copyright (c) 2017 Eric B. Decker, Daniel J. Maltbie
 * All rights reserved.
 */

#include "Si446xRadio.h"
#include "Tagnet.h"

configuration TagnetMonitorC {}
implementation {
  components MainC;
  components SystemBootC;
  components TagnetMonitorP;
  MainC.SoftwareInit            -> TagnetMonitorP;
  TagnetMonitorP.Boot           -> SystemBootC.Boot;

  components TagnetC;
  TagnetMonitorP.Tagnet         -> TagnetC;
  TagnetMonitorP.TagnetName     -> TagnetC;
  TagnetMonitorP.TagnetPayload  -> TagnetC;
  TagnetMonitorP.TagnetTLV      -> TagnetC;
  TagnetMonitorP.TagnetHeader   -> TagnetC;

  components GPS0C              as GpsPort;
  components GPSmonitorC;
  GPSmonitorC.GPSReceive        -> GpsPort;
  TagnetC.InfoSensGpsXyz        -> GPSmonitorC;

  components TagnetSysExecC;
  TagnetC.SysActive             -> TagnetSysExecC.SysActive;
  TagnetC.SysBackup             -> TagnetSysExecC.SysBackup;
  TagnetC.SysGolden             -> TagnetSysExecC.SysGolden;
  TagnetC.SysNIB                -> TagnetSysExecC.SysNIB;
  TagnetC.SysRunning            -> TagnetSysExecC.SysRunning;

  components TagnetPollExecC;
  TagnetC.PollCount             -> TagnetPollExecC.PollCount;
  TagnetC.PollEvent             -> TagnetPollExecC.PollEvent;

  components DblkByteStorageC;
  TagnetC.DblkBytes             -> DblkByteStorageC.DblkBytes;
  TagnetC.DblkNote              -> DblkByteStorageC.DblkNote;

  components PanicByteStorageC;
  TagnetC.PanicBytes            -> PanicByteStorageC.PanicBytes;

  components new TimerMilliC()  as Timer0;
  TagnetMonitorP.rcTimer        -> Timer0;
  components new TimerMilliC()  as Timer1;
  TagnetMonitorP.txTimer        -> Timer1;

  components LocalTimeMilliC;
  TagnetMonitorP.LocalTime      -> LocalTimeMilliC;

  components RandomC;
  TagnetMonitorP.Random         -> RandomC;

  components LedsC;
  TagnetMonitorP.Leds           -> LedsC;

  components new TaskletC();
  Si446xDriverLayerC.Tasklet    -> TaskletC;
  components new RadioAlarmC();
  Si446xDriverLayerC.RadioAlarm -> RadioAlarmC.RadioAlarm[unique(UQ_SI446X_RADIO_ALARM)];
  Si446xDriverLayerC.Tasklet    -> TaskletC;
  RadioAlarmC.Alarm             -> Si446xDriverLayerC;
  RadioAlarmC.Tasklet           -> TaskletC;

  // -------- MetadataFlags
  components new MetadataFlagsLayerC();
  MetadataFlagsLayerC.SubPacket -> Si446xDriverLayerC;

  components Si446xDriverLayerC;
  TagnetMonitorP.RadioState     -> Si446xDriverLayerC;
  TagnetMonitorP.RadioSend      -> Si446xDriverLayerC;
  TagnetMonitorP.RadioReceive   -> Si446xDriverLayerC;
  Si446xDriverLayerC.TransmitPowerFlag -> MetadataFlagsLayerC.PacketFlag[unique(UQ_SI446X_METADATA_FLAGS)];
  Si446xDriverLayerC.RSSIFlag   -> MetadataFlagsLayerC.PacketFlag[unique(UQ_SI446X_METADATA_FLAGS)];

  components PlatformC;
  TagnetMonitorP.Platform       -> PlatformC;

  components PanicC;
  TagnetMonitorP.Panic          -> PanicC;
}
