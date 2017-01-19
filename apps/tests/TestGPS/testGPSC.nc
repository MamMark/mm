/*
 * Copyright (c) 2012, 2014 Eric B. Decker
 * All rights reserved.
 */

configuration testGPSC {}
implementation {
  components MainC, testGPSP;
  MainC.SoftwareInit -> testGPSP;
  testGPSP -> MainC.Boot;

  components PlatformC;
  components GPS0C as GpsPort;
  testGPSP.HW -> GpsPort;
  testGPSP.GPSControl -> GpsPort;
  testGPSP.Platform -> PlatformC;

  components new TimerMilliC() as Timer;
  testGPSP.testTimer -> Timer;

  components LocalTimeMilliC;
  testGPSP.LocalTime -> LocalTimeMilliC;

}
