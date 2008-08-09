/*
 * Copyright (c) 2008 Eric B. Decker
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
  components MainC, GPSMsgP;
  MainC.SoftwareInit -> GPSMsgP;
  GPSMsg = GPSMsgP;
  GPSMsgControl = GPSMsgP;

  components PanicC;
  GPSMsgP.Panic -> PanicC;

  components CollectC;
  GPSMsgP.Collect -> CollectC;

  components LocalTimeMilliC;
  GPSMsgP.LocalTime -> LocalTimeMilliC;

#ifdef notdef
  components new TimerMilliC() as GpsTimer;
  GPSMsgP.GpsTimer -> GpsTimer;
#endif
}
