/*
 * Copyright (c) 2008, 2010, Eric B. Decker
 * All rights reserved.
 */

#include "sensors.h"

configuration BattC {
  provides interface StdControl;
}

implementation {
  components MainC, BattP;
  MainC.SoftwareInit -> BattP;
  StdControl = BattP;

  components RegimeC, new TimerMilliC() as PeriodTimer;
  BattP.RegimeCtrl -> RegimeC.Regime;
  BattP.PeriodTimer -> PeriodTimer;

  components AdcC;
  BattP.Adc -> AdcC.Adc[SNS_ID_BATT];
  AdcC.SensorPowerControl[SNS_ID_BATT] -> BattP;

  components AdcP;
  BattP.AdcConfigure <- AdcP.Config[SNS_ID_BATT];

  components CollectC;
  BattP.Collect -> CollectC;

  components Hpl_MM_hwC;
  BattP.HW -> Hpl_MM_hwC;

  components mmControlC;
  BattP.mmControl -> mmControlC.mmControl[SNS_ID_BATT];

  components mmCommDataC;
  BattP.mmCommData -> mmCommDataC.mmCommData[SNS_ID_BATT];

  components CradleC;
  BattP.Docked -> CradleC;

  components PanicC;
  BattP.Panic -> PanicC;
}
