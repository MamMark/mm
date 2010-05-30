/*
 * Copyright (c) 2008, 2010, Eric B. Decker
 * All rights reserved.
 */

#include "sensors.h"

configuration TempC {
  provides interface StdControl;
}

implementation {
  components TempP;
  StdControl = TempP;

  components RegimeC, new TimerMilliC() as PeriodTimer;
  TempP.RegimeCtrl -> RegimeC.Regime;
  TempP.PeriodTimer -> PeriodTimer;

  components AdcC;
  TempP.Adc -> AdcC.Adc[SNS_ID_TEMP];
  AdcC.SensorPowerControl[SNS_ID_TEMP] -> TempP;

  components AdcP;
  TempP.AdcConfigure <- AdcP.Config[SNS_ID_TEMP];

  components CollectC;
  TempP.Collect -> CollectC;

  components Hpl_MM_hwC;
  TempP.HW -> Hpl_MM_hwC;

  components mmControlC;
  TempP.mmControl -> mmControlC.mmControl[SNS_ID_TEMP];

  components CommDTC;
  TempP.CommDT -> CommDTC.CommDT[SNS_ID_TEMP];

  components PanicC;
  TempP.Panic -> PanicC;
}
