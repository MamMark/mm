/*
 * Copyright (c) 2008, Eric B. Decker
 * All rights reserved.
 */

#include "stream_storage.h"

configuration mm3AppC {}
implementation {
  components SystemBootC, mm3C;
  mm3C -> SystemBootC.Boot;
  
  components RegimeC;
  mm3C.Regime -> RegimeC;
  
#ifdef notdef
  components HplMM3AdcC;
  mm3C.HW -> HplMM3AdcC;
#endif

  components PanicC;
  mm3C.Panic -> PanicC;

  components CollectC;
  mm3C.Collect -> CollectC;

  components StreamStorageC;
  mm3C.StreamStorageFull -> StreamStorageC;

  mm3C.SSR -> StreamStorageC.SSR[SSR_CLIENT_TEST];
  
  /*
   * Include sensor components.  No need to wire.  They will
   * start when regimeChange() is signalled.
   */
  components CradleC, BattC, TempC, SalC, AccelC, PTempC, PressC, SpeedC, MagC;

  /*
   * Include modules for Serial multiplexing
   */
  components SerialNullC;
}
