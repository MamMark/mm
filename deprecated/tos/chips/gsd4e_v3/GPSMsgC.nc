/*
 * Copyright (c) 2008, 2010, 2017 Eric B. Decker
 * All rights reserved.
 */

/**
 * @author Eric B. Decker (cire831@gmail.com)
 * @date Aug 1, 2008
 */

configuration GPSMsgC {
  provides {
    interface GPSMsg;
    interface StdControl as GPSMsgControl;
  }
}

implementation {
  components MainC;
  components GPSMsgP;
  MainC.SoftwareInit -> GPSMsgP;
  GPSMsg = GPSMsgP;
  GPSMsgControl = GPSMsgP;

  components PanicC;
  GPSMsgP.Panic -> PanicC;

#ifdef notdef
  components CollectC;
  GPSMsgP.Collect -> CollectC;
  GPSMsgP.LogEvent -> CollectC;
#endif

  components LocalTimeMilliC;
  GPSMsgP.LocalTime -> LocalTimeMilliC;

  components new TimerMilliC() as MsgTimer;
  GPSMsgP.MsgTimer -> MsgTimer;

  components GPS0C;
  GPSMsgP.GPSControl -> GPS0C;

#ifdef notdef
  components mmControlC;
  GPSMsgP.Surface -> mmControlC;

  components DTSenderC;
  GPSMsgP.DTSender -> DTSenderC.DTSender[SNS_ID_NONE];
#endif
}
