/*
 * Copyright (c) 2015, 2017 Eric B. Decker, Daniel J. Maltbie
 * All rights reserved.
 */
#include "si446xRadio.h"
#include "Tagnet.h"
#include "TagnetTLV.h"

configuration testTagnetC {}
implementation {

  components MainC, testTagnetP;
  MainC.SoftwareInit -> testTagnetP;
  testTagnetP -> MainC.Boot;

  components TagnetC;
  testTagnetP.Tagnet -> TagnetC;
  testTagnetP.TagnetName -> TagnetC;
  testTagnetP.TagnetPayload -> TagnetC;
  testTagnetP.TagnetTLV -> TagnetC;
  testTagnetP.TagnetHeader -> TagnetC;
  TagnetC.InfoSensGpsPos -> testTagnetP;

//  components new  TagnetNamePollP   (TN_POLL_EV_ID)   as PollEvLf;
//  PollEvLf.Super -> testTagnetP.TagnetMessage[unique(UQ_TN_ROOT)];

  components new TimerMilliC() as Timer0;
  testTagnetP.rcTimer -> Timer0;

  components new TimerMilliC() as Timer1;
  testTagnetP.txTimer -> Timer1;

  components LocalTimeMilliC;
  testTagnetP.LocalTime -> LocalTimeMilliC;

  components RandomC;
  testTagnetP.Random -> RandomC;

  components LedsC;
  testTagnetP.Leds -> LedsC;

  components new TaskletC();
  components new RadioAlarmC();
  Si446xDriverLayerC.Tasklet -> TaskletC;

  Si446xDriverLayerC.RadioAlarm -> RadioAlarmC.RadioAlarm[unique(UQ_SI446X_RADIO_ALARM)];
  RadioAlarmC.Alarm -> Si446xDriverLayerC;
  RadioAlarmC.Tasklet -> TaskletC;

// -------- MetadataFlags
  components new MetadataFlagsLayerC();
  MetadataFlagsLayerC.SubPacket -> Si446xDriverLayerC;


  components Si446xDriverLayerC;
  testTagnetP.RadioState -> Si446xDriverLayerC;
  testTagnetP.RadioSend -> Si446xDriverLayerC;
  testTagnetP.RadioReceive -> Si446xDriverLayerC;
  Si446xDriverLayerC.TransmitPowerFlag -> MetadataFlagsLayerC.PacketFlag[unique(UQ_SI446X_METADATA_FLAGS)];
  Si446xDriverLayerC.RSSIFlag -> MetadataFlagsLayerC.PacketFlag[unique(UQ_SI446X_METADATA_FLAGS)];

  components PanicC;
  testTagnetP.Panic -> PanicC;
}
