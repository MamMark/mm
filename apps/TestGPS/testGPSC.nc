/*
 * Copyright (c) 2008, Eric B. Decker
 * All rights reserved.
 */

configuration testGPSC {}
implementation {
  components SystemBootC, testGPSP;
  SystemBootC.SoftwareInit -> testGPSP;
  testGPSP -> SystemBootC.Boot;
  
  components PanicC;
  testGPSP.Panic -> PanicC;

  components GPSC;
  testGPSP.GPSControl -> GPSC;

  components StreamStorageC;
  testGPSP.StreamStorageFull -> StreamStorageC;

  components mm3CommDataC;
  testGPSP.mm3CommData -> mm3CommDataC.mm3CommData[SNS_ID_NONE];
}
