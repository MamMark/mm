/*
 * Copyright (c) 2008, 2010, Eric B. Decker
 * All rights reserved.
 */

#include "stream_storage.h"

configuration mmAppC {}
implementation {
  components SystemBootC, mmC;
  mmC -> SystemBootC.Boot;
  
  components RegimeC;
  mmC.Regime -> RegimeC;
  
#ifdef notdef
  components HplMMAdcC;
  mmC.HW -> HplMMAdcC;
#endif

  components PanicC;
  mmC.Panic -> PanicC;

  components CollectC;
  mmC.Collect -> CollectC;

  components StreamStorageC;
  mmC.StreamStorageFull -> StreamStorageC;

  mmC.SSR -> StreamStorageC.SSR[SSR_CLIENT_TEST];
  
  /*
   * Include sensor components.  No need to wire.  They will
   * start when regimeChange() is signalled.
   */
  components CradleC, BattC, TempC, SalC, AccelC, PTempC, PressC, SpeedC, MagC;
}
