/*
 * Copyright (c) 2008, Eric B. Decker
 * All rights reserved.
 */

configuration mm3AppC {}
implementation {
  components SystemBootC, mm3C;
  SystemBootC.SoftwareInit -> mm3C;
  mm3C -> SystemBootC.Boot;
  
  components RegimeC;
  mm3C.Regime -> RegimeC;
  
  components HplMM3AdcC;
  mm3C.HW -> HplMM3AdcC;

  components PanicC;
  mm3C.Panic -> PanicC;

  components new TimerMilliC() as SyncTimerC;
  mm3C.SyncTimer -> SyncTimerC;

  components mm3CommDataC;
  mm3C.mm3CommData -> mm3CommDataC.mm3CommData[SNS_ID_NONE];

  components CollectC;
  mm3C.Collect -> CollectC;

  /*
   * Include sensor components.  No need to wire.  They will
   * start when regimeChange() is signalled.
   */
  components BattC, TempC, SalC, AccelC, PTempC, PressC, SpeedC, MagC;
  
#ifdef TEST_GPS
//  components GPSByteCollectC;
//  mm3C.GPSControl -> GPSByteCollectC.GPSByteControl;

  components GPSC;
  mm3C.GPSControl -> GPSC;
#endif

#ifdef notdef
  components AdcC;
  mm3C.Adc -> AdcC.Adc[SNS_ID_NONE];
#endif

}
