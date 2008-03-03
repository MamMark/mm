/*
 * Copyright (c) 2008, Eric B. Decker
 * All rights reserved.
 */

#include "sensors.h"

configuration TempC {
  provides interface StdControl;
}
implementation {
  components MainC, TempP;
  MainC.SoftwareInit -> TempP;
  StdControl = TempP;

  components RegimeC, new TimerMilliC() as PeriodTimer;
  TempP.RegimeCtrl -> RegimeC.Regime;
  TempP.PeriodTimer -> PeriodTimer;

  components AdcC;
  TempP.Adc -> AdcC.Adc[SNS_ID_TEMP];

  components AdcP;
  TempP.AdcConfigure <- AdcP.Config[SNS_ID_TEMP];

  components CollectC;
  TempP.Collect -> CollectC;
}
