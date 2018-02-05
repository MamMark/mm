/*
 * Copyright (c) 2012, 2014, 2017-2018 Eric B. Decker, Daniel J. Maltbie
 * All rights reserved.
 */

configuration testGPSC {
  provides interface TagnetAdapter<tagnet_gps_xyz_t> as InfoSensGpsXyz;
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
  GPSmonitorC.GPSState    -> GpsPort;
  GPSmonitorC.GPSControl  -> GpsPort;
  GPSmonitorC.GPSReceive  -> GpsPort;
  GPSmonitorC.GPSTransmit -> GpsPort;

  InfoSensGpsXyz           = GPSmonitorC;

  components new TimerMilliC() as Timer;
  testGPSP.testTimer -> Timer;

  components LocalTimeMilliC;
  testGPSP.LocalTime -> LocalTimeMilliC;
}
