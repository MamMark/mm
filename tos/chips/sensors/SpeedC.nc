/*
 * Copyright (c) 2008, 2010, Eric B. Decker
 * All rights reserved.
 */

#include "sensors.h"

configuration SpeedC {
  provides interface StdControl;
}

implementation {
  components SpeedP;
  StdControl = SpeedP;

  components RegimeC, new TimerMilliC() as PeriodTimer;
  SpeedP.RegimeCtrl -> RegimeC.Regime;
  SpeedP.PeriodTimer -> PeriodTimer;

  components AdcC;
  SpeedP.Adc -> AdcC.Adc[SNS_ID_SPEED];
  AdcC.SensorPowerControl[SNS_ID_SPEED] -> SpeedP;

  components AdcP;
  SpeedP.AdcConfigure <- AdcP.Config[SNS_ID_SPEED];

  components CollectC;
  SpeedP.Collect -> CollectC;

  components Hpl_MM_hwC;
  SpeedP.HW -> Hpl_MM_hwC;

  components mmControlC;
  SpeedP.mmControl -> mmControlC.mmControl[SNS_ID_SPEED];

  components CommDTC;
  SpeedP.CommDT -> CommDTC.CommDT[SNS_ID_SPEED];

  components PanicC;
  SpeedP.Panic -> PanicC;
}
