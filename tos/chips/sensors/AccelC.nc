/*
 * Copyright (c) 2008, 2010, Eric B. Decker
 * All rights reserved.
 */

#include "sensors.h"

configuration AccelC {
  provides interface StdControl;
}

implementation {
  components AccelP;
  StdControl = AccelP;

  components RegimeC, new TimerMilliC() as PeriodTimer;
  AccelP.RegimeCtrl -> RegimeC.Regime;
  AccelP.PeriodTimer -> PeriodTimer;

  components AdcC;
  AccelP.Adc -> AdcC.Adc[SNS_ID_ACCEL];
  AdcC.SensorPowerControl[SNS_ID_ACCEL] -> AccelP;

  components AdcP;
  AccelP.AdcConfigure <- AdcP.Config[SNS_ID_ACCEL];

  components CollectC;
  AccelP.Collect -> CollectC;

  components Hpl_MM_hwC;
  AccelP.HW -> Hpl_MM_hwC;

  components mmControlC;
  AccelP.mmControl -> mmControlC.mmControl[SNS_ID_ACCEL];

  components CommDTC;
  AccelP.CommDT -> CommDTC.CommDT[SNS_ID_ACCEL];

  components PanicC;
  AccelP.Panic -> PanicC;
}
