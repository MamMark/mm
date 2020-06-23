/*
 * Copyright (c) 2008, 2010, 2019, Eric B. Decker
 * All rights reserved.
 */

configuration TempC {
}

implementation {
  components TempP;
  components RegimeC, new TimerMilliC() as PeriodTimer;
  TempP.RegimeCtrl -> RegimeC.Regime;
  TempP.PeriodTimer -> PeriodTimer;

  components TmpPC, TmpXC;
  TempP.TmpP -> TmpPC;
  TempP.TmpX -> TmpXC;

  components CollectC;
  TempP.Collect -> CollectC;
}
