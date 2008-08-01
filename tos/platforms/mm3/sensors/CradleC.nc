/*
 * Copyright (c) 2008, Eric B. Decker
 * All rights reserved.
 */

#include "sensors.h"

configuration CradleC {
  provides interface StdControl;
}

implementation {
  components MainC, CradleP;
  MainC.SoftwareInit -> CradleP;
  StdControl = CradleP;

  components RegimeC, new TimerMilliC() as PeriodTimer;
  CradleP.RegimeCtrl -> RegimeC.Regime;
  CradleP.PeriodTimer -> PeriodTimer;

  components AdcC;
  CradleP.Adc -> AdcC.Adc[SNS_ID_CRADLE];
  AdcC.SensorPowerControl[SNS_ID_CRADLE] -> CradleP;

  components AdcP;
  CradleP.AdcConfigure <- AdcP.Config[SNS_ID_CRADLE];

  components HplMM3AdcC;
  CradleP.HW -> HplMM3AdcC;

  components mm3ControlC;
  CradleP.mm3Control -> mm3ControlC.mm3Control[SNS_ID_CRADLE];

  components PanicC;
  CradleP.Panic -> PanicC;
}
