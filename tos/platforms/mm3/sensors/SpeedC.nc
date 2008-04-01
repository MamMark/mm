/*
 * Copyright (c) 2008, Eric B. Decker
 * All rights reserved.
 */

#include "sensors.h"

configuration SpeedC {
  provides interface StdControl;
}

implementation {
  components MainC, SpeedP;
  MainC.SoftwareInit -> SpeedP;
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

  components HplMM3AdcC;
  SpeedP.HW -> HplMM3AdcC;
}
