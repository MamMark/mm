/*
 * Copyright (c) 2012 Eric B. Decker
 * All rights reserved.
 *
 * Reworked for the org4472 gps spi chip.
 * uses PlatformGPS_SPI for port selection.
 *
 * @author Eric B. Decker (cire831@gmail.com)
 * @date May 23, 2012
 */

configuration GPSC {
  provides {
    interface StdControl as GPSControl;
//    interface Boot as GPSBoot;
  }
//  uses interface Boot;
}

implementation {
  components MainC, GPSP;
  MainC.SoftwareInit -> GPSP;
  GPSControl = GPSP;
//  GPSBoot = GPSP;
//  Boot = GPSP.Boot;

//  components GPSMsgC;
//  GPSP.GPSMsg -> GPSMsgC;
//  GPSP.GPSMsgControl -> GPSMsgC;

  components Hpl_mm5t_hwC;
  GPSP.HW -> Hpl_mm5t_hwC;

  components LocalTimeMilliC;
  GPSP.LocalTime -> LocalTimeMilliC;

  components new TimerMilliC() as GPSTimer;
  GPSP.GPSTimer -> GPSTimer;

//  components PlatformGPS_SPIC as UsciC;
//  GPSP.Usci -> UsciC;

  components PlatformGPS_SPIC as SpiC;
  GPSP.SpiBlock     -> SpiC;
  GPSP.SpiResource  -> SpiC;
  GPSP.SpiConfigure <- SpiC;
  
  components PanicC;
  GPSP.Panic -> PanicC;

//  components TraceC;
//  GPSP.Trace -> TraceC;

//  components CollectC;
//  GPSP.LogEvent -> CollectC;
}
