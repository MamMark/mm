/*
 * Copyright (c) 2012, 2014, 2017 Eric B. Decker, Daniel J. Maltbie
 * All rights reserved.
 */

configuration testGPSC {
  provides interface TagnetAdapter<tagnet_gps_xyz_t> as InfoSensGpsXYZ;
}
implementation {
  components testGPSP, SystemBootC;
  testGPSP.Boot -> SystemBootC.Boot;

  components PlatformC;
  components GPS0C as GpsPort;
#ifdef notdef
  testGPSP.HW -> GpsPort;
#endif
  testGPSP.GPSState   -> GpsPort;
  testGPSP.Platform   -> PlatformC;

  components GPSmonitorC;
  GPSmonitorC.GPSReceive -> GpsPort;
  InfoSensGpsXYZ = GPSmonitorC;

  components new TimerMilliC() as Timer;
  testGPSP.testTimer -> Timer;

  components LocalTimeMilliC;
  testGPSP.LocalTime -> LocalTimeMilliC;
}
