/*
 * Copyright (c) 2012, 2014 Eric B. Decker
 * All rights reserved.
 */

configuration testGPSC {}
implementation {
  components MainC, testGPSP;
  MainC.SoftwareInit -> testGPSP;
  testGPSP -> MainC.Boot;

  components Hpl_MM_hwC as HW;
  testGPSP.HW -> HW;

  components new TimerMilliC() as Timer;
  testGPSP.testTimer -> Timer;

  components LocalTimeMilliC;
  testGPSP.LocalTime -> LocalTimeMilliC;

  components ORG4472C;
  testGPSP.GPSControl -> ORG4472C;
}
