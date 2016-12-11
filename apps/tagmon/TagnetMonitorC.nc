/*
 * Copyright (c) 2015 Eric B. Decker
 * All rights reserved.
 */

configuration TagnetMonitorC {}
implementation {

#define UQ_METADATA_FLAGS "UQ_SI446X_METADATA_FLAGS"
#define UQ_RADIO_ALARM    "UQ_SI446X_RADIO_ALARM"

  components MainC, TagnetMonitorP;
  MainC.SoftwareInit -> TagnetMonitorP;
  TagnetMonitorP -> MainC.Boot;

  components new TimerMilliC() as Timer0;
  TagnetMonitorP.rcTimer -> Timer0;
  components new TimerMilliC() as Timer1;
  TagnetMonitorP.txTimer -> Timer1;
  /*
  components new TimerMilliC() as Timer2;
  TagnetMonitorP.pgTimer -> Timer2;
  */
  components LocalTimeMilliC;
  TagnetMonitorP.LocalTime -> LocalTimeMilliC;

  components RandomC;
  TagnetMonitorP.Random -> RandomC;

  components LedsC;
  TagnetMonitorP.Leds -> LedsC;

//  components Si446xRadioC;
  components new TaskletC();
  Si446xDriverLayerC.Tasklet -> TaskletC;
  components new RadioAlarmC();
  Si446xDriverLayerC.RadioAlarm -> RadioAlarmC.RadioAlarm[unique(UQ_RADIO_ALARM)];
  Si446xDriverLayerC.Tasklet -> TaskletC;
  RadioAlarmC.Alarm -> Si446xDriverLayerC;
  RadioAlarmC.Tasklet -> TaskletC;
//

// -------- MetadataFlags
  components new MetadataFlagsLayerC();
  MetadataFlagsLayerC.SubPacket -> Si446xDriverLayerC;


  components Si446xDriverLayerC;
  TagnetMonitorP.RadioState -> Si446xDriverLayerC;
  TagnetMonitorP.RadioSend -> Si446xDriverLayerC;
  TagnetMonitorP.RadioReceive -> Si446xDriverLayerC;
  Si446xDriverLayerC.TransmitPowerFlag -> MetadataFlagsLayerC.PacketFlag[unique(UQ_METADATA_FLAGS)];
  Si446xDriverLayerC.RSSIFlag -> MetadataFlagsLayerC.PacketFlag[unique(UQ_METADATA_FLAGS)];

  components PanicC;
  TagnetMonitorP.Panic -> PanicC;
}
