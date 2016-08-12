/*
 * Copyright (c) 2012, 2014-2016 Eric B. Decker
 * All rights reserved.
 *
 * GSD4E gps spi chip.  SirfStarIV
 * uses hardware/gsd4e/HplGsd4e for port selection.
 *
 * @author Eric B. Decker (cire831@gmail.com)
 * @date May 23, 2012
 * @updated Feb 9, 2014 for M10478 GSD4e gps
 */

configuration Gsd4eC {
  provides {
    interface SplitControl as GPSControl;
  }
}

implementation {
  components MainC, Gsd4eP;
  MainC.SoftwareInit -> Gsd4eP;
  GPSControl = Gsd4eP;

  components GPSMsgC;
  Gsd4eP.GPSMsgS       -> GPSMsgC;
  Gsd4eP.GPSMsgControl -> GPSMsgC;

  components HplGsd4eC as HW;
  Gsd4eP.HW -> HW;
  Gsd4eP.SpiBlock -> HW;
  Gsd4eP.SpiByte  -> HW;

  components LocalTimeMilliC;
  Gsd4eP.LocalTime -> LocalTimeMilliC;

  components new TimerMilliC() as GPSTimer;
  Gsd4eP.GPSTimer -> GPSTimer;

  components PlatformC;
  Gsd4eP.Platform -> PlatformC;

  components PanicC;
  Gsd4eP.Panic -> PanicC;

//  components TraceC;
//  Gsd4eP.Trace -> TraceC;
}
