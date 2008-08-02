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
    interface GPSByte;
    interface StdControl as GPSMsgControl;
  }
}

implementation {
  components GPSMsgP;
  GPSByte = GPSMsgP;
  GPSMsgControl = GPSMsgP;

#ifdef notdef
  components LocalTimeMilliC;
  GPSMsgP.LocalTime -> LocalTimeMilliC;

  components new TimerMilliC() as GpsTimer;
  GPSMsgP.GpsTimer -> GpsTimer;

  components PanicC;
  GPSMsgP.Panic -> PanicC;
#endif
}
