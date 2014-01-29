/*
 * Copyright (c) 2012, 2014 Eric B. Decker
 * All rights reserved.
 *
 * ORG4472 gps spi chip.
 * uses PlatformGPS_SPI for port selection.
 *
 * @author Eric B. Decker (cire831@gmail.com)
 * @date May 23, 2012
 */

configuration ORG4472C {
  provides {
    interface StdControl as GPSControl;
  }
}

implementation {
  components MainC, ORG4472P;
  MainC.SoftwareInit -> ORG4472P;
  GPSControl = ORG4472P;

  components GPSMsgC;
  ORG4472P.GPSMsgS       -> GPSMsgC;
  ORG4472P.GPSMsgControl -> GPSMsgC;

  components Hpl_MM_hwC as HW;
  ORG4472P.HW -> HW;

  components LocalTimeMilliC;
  ORG4472P.LocalTime -> LocalTimeMilliC;

  components new TimerMilliC() as GPSTimer;
  ORG4472P.GPSTimer -> GPSTimer;

  components new Msp430UsciSpiB1C() as SpiC;
  ORG4472P.SpiBlock     -> SpiC;
  ORG4472P.SpiByte      -> SpiC;
  ORG4472P.SpiResource  -> SpiC;
  ORG4472P.Msp430UsciConfigure <- SpiC;

  components PanicC;
  ORG4472P.Panic -> PanicC;

//  components TraceC;
//  ORG4472P.Trace -> TraceC;
}
