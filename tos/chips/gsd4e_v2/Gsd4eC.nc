/*
 * Copyright (c) 2012, 2014-2015 Eric B. Decker
 * All rights reserved.
 *
 * GSD4E gps spi chip.  SirfStarIV
 * uses PlatformGPS_SPI for port selection.
 *
 * @author Eric B. Decker (cire831@gmail.com)
 * @date May 23, 2012
 * @updated Feb 9, 2014 for M10478 GSD4e gps
 */

configuration Gsd4eC {
  provides {
    interface StdControl as GPSControl;
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

  components LocalTimeMilliC;
  Gsd4eP.LocalTime -> LocalTimeMilliC;

  components new TimerMilliC() as GPSTimer;
  Gsd4eP.GPSTimer -> GPSTimer;

  components PlatformC;
  Gsd4eP.Platform -> PlatformC;

  components new Msp430UsciSpiA3C() as SpiC;
  Gsd4eP.SpiBlock     -> SpiC;
  Gsd4eP.SpiByte      -> SpiC;
  Gsd4eP.SpiResource  -> SpiC;
  Gsd4eP.Msp430UsciConfigure <- SpiC;

  components PanicC;
  Gsd4eP.Panic -> PanicC;

//  components TraceC;
//  Gsd4eP.Trace -> TraceC;
}
