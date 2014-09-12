/*
 * Copyright (c) 2012 Eric B. Decker
 * All rights reserved.
 */
 
/**
 * @author Eric B. Decker (cire831@gmail.com)
 * @date June 4, 2012
 *
 * reworked for SPI based ORG4472
 * Synchronous GPSMsgS.
 */

configuration GPSMsgC {
  provides {
    interface GPSMsgS;
    interface StdControl as GPSMsgControl;
  }
}

implementation {
  components MainC, GPSMsgP;
  MainC.SoftwareInit -> GPSMsgP;
  GPSMsgS       = GPSMsgP;
  GPSMsgControl = GPSMsgP;

  components PanicC;
  GPSMsgP.Panic -> PanicC;

//  components CollectC;
//  GPSMsgP.Collect -> CollectC;
//  GPSMsgP.LogEvent -> CollectC;

  components LocalTimeMilliC;
  GPSMsgP.LocalTime -> LocalTimeMilliC;

  components new TimerMilliC() as MsgTimer;
  GPSMsgP.MsgTimer -> MsgTimer;

  components ORG4472C;
  GPSMsgP.GPSControl -> ORG4472C;

//  components mmControlC;
//  GPSMsgP.Surface -> mmControlC;

//  components DTSenderC;
//  GPSMsgP.DTSender -> DTSenderC.DTSender[SNS_ID_NONE];
}
