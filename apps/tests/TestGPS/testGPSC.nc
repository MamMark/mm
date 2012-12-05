/*
 * Copyright (c) 2012, Eric B. Decker
 * All rights reserved.
 */

configuration testGPSC {}
implementation {
  components MainC, testGPSP;
  MainC.SoftwareInit -> testGPSP;
  testGPSP -> MainC.Boot;

  components Hpl_MM5t_hwC as HW;
  testGPSP.HW -> HW;

  components new TimerMilliC() as Timer;
  testGPSP.testTimer -> Timer;

  components LocalTimeMilliC;
  testGPSP.LocalTime -> LocalTimeMilliC;

  components ORG4472C;
  testGPSP.GPSControl -> ORG4472C;
}
