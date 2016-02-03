/*
 * Copyright (c) 2015 Eric B. Decker
 * All rights reserved.
 */

configuration testRadioC {}
implementation {

#define UQ_METADATA_FLAGS "UQ_SI446X_METADATA_FLAGS"
#define UQ_RADIO_ALARM    "UQ_SI446X_RADIO_ALARM"

  components MainC, testRadioP;
  MainC.SoftwareInit -> testRadioP;
  testRadioP -> MainC.Boot;

  components new TimerMilliC() as Timer;
  testRadioP.testTimer -> Timer;

  components LocalTimeMilliC;
  testRadioP.LocalTime -> LocalTimeMilliC;

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
  testRadioP.RadioState -> Si446xDriverLayerC;
  testRadioP.RadioSend -> Si446xDriverLayerC;
  testRadioP.RadioReceive -> Si446xDriverLayerC;
  Si446xDriverLayerC.TransmitPowerFlag -> MetadataFlagsLayerC.PacketFlag[unique(UQ_METADATA_FLAGS)];
  Si446xDriverLayerC.RSSIFlag -> MetadataFlagsLayerC.PacketFlag[unique(UQ_METADATA_FLAGS)];

  components PanicC;
  testRadioP.Panic -> PanicC;
}
