/*
 * Copyright (c) 2008, 2010, Eric B. Decker
 * All rights reserved.
 */

#include "stream_storage.h"

configuration mmC {}
implementation {
  components SystemBootC, mmP;
  mmP.Boot -> SystemBootC.Boot;
  
  components RegimeC;
  mmP.Regime -> RegimeC;
  
  components PanicC;
  mmP.Panic -> PanicC;

  components CollectC;
  mmP.Collect -> CollectC;

  components SSWriteC;
  mmP.SSFull -> SSWriteC;

  /*
   * Include sensor components.  No need to wire.  They will
   * start when regimeChange() is signalled.
   */
  components CradleC, BattC, TempC, SalC, AccelC, PTempC, PressC, SpeedC, MagC;

  components CmdHandlerC;
}
