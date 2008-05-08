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
  
  /*
   * Include Threaded implementation of the SD Stream Storage Writer
   */
  components StreamStorageWriterC;
  
  components HplMM3AdcC;
  mm3C.HW -> HplMM3AdcC;

  components AdcC;
  mm3C.Adc -> AdcC.Adc[SNS_ID_NONE];

  components PanicC;
  mm3C.Panic -> PanicC;

  /*
   * Include sensor components.  No need to wire.  They will
   * start when regimeChange() is signalled.
   */
  components BattC, TempC, SalC, AccelC, PTempC, PressC, SpeedC, MagC;
  
#ifdef TEST_SS
  components HplMsp430Usart1C as UsartC;
  mm3C.Usart -> UsartC;
#endif

//  components GPSByteCollectC;
//  mm3C.GPSControl -> GPSByteCollectC.GPSControl;

#ifdef TEST_GPS
  components GPSC;
  mm3C.GPSControl -> GPSC;
#endif
}
