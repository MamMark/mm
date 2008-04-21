/*
 * Copyright (c) 2008, Eric B. Decker
 * All rights reserved.
 */

configuration mm3AppC {}
implementation {
  components SystemBootC, mm3C;

/*
 * What is the purpose of the following
 * Why call mm3C.Init from SystemBootC?
 * Rather than MainC.SoftwareInit?
 */

  SystemBootC.SoftwareInit -> mm3C;
  mm3C -> SystemBootC.Boot;
  
  components RegimeC;
  mm3C.Regime -> RegimeC;
  
  components LedsC;
  mm3C.Leds -> LedsC;

  /*
   * Include sensor components.  No need to wire.  They will
   * start when regimeChange() is signalled.
   */
  components BattC, TempC, SalC, AccelC, PTempC, PressC, SpeedC, MagC;

  components HplMM3AdcC;
  mm3C.HW -> HplMM3AdcC;

  components AdcC;
  mm3C.Adc -> AdcC.Adc[SNS_ID_NONE];

#ifdef USE_SD
  components SDC, HplMsp430Usart1C as UsartC;
  mm3C.SD -> SDC;
  mm3C.Usart -> UsartC;
#endif

//  components GPSByteCollectC;
//  mm3C.GPSControl -> GPSByteCollectC.GPSControl;

  components PanicC;
  mm3C.Panic -> PanicC;
}
