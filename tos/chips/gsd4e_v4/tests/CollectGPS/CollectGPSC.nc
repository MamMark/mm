/*
 * Copyright (c) 2017 Eric B. Decker
 * All rights reserved.
 */

configuration CollectGPSC {}
implementation {
  components CollectGPSP, SystemBootC;
  CollectGPSP.Boot -> SystemBootC;

  components GPS0C as GpsPort;
  CollectGPSP.GPSReceive -> GpsPort;

  components CollectC;
  CollectGPSP.Collect -> CollectC;
}
