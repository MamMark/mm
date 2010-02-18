/*
 * Copyright (c) 2008, 2010, Eric B. Decker
 * All rights reserved.
 */

#include "sensors.h"

configuration CradleC {
  provides {
    interface StdControl;
    interface Docked;
  }
}

implementation {
  components MainC, CradleP;
  MainC.SoftwareInit -> CradleP;
  StdControl = CradleP;
  Docked = CradleP;

  components RegimeC, new TimerMilliC() as PeriodTimer;
  CradleP.RegimeCtrl -> RegimeC.Regime;
  CradleP.PeriodTimer -> PeriodTimer;

  components AdcC;
  CradleP.Adc -> AdcC.Adc[SNS_ID_CRADLE];
  AdcC.SensorPowerControl[SNS_ID_CRADLE] -> CradleP;

  components AdcP;
  CradleP.AdcConfigure <- AdcP.Config[SNS_ID_CRADLE];

  components CollectC;
  CradleP.Collect -> CollectC;
  CradleP.LogEvent -> CollectC;

  components Hpl_MM_hwC;
  CradleP.HW -> Hpl_MM_hwC;

  components mmCommDataC;
  CradleP.mmCommData -> mmCommDataC.mmCommData[SNS_ID_CRADLE];

  components PanicC;
  CradleP.Panic -> PanicC;
}
