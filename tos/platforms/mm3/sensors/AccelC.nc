/*
 * Copyright (c) 2008, Eric B. Decker
 * All rights reserved.
 */

#include "sensors.h"

configuration AccelC {
  provides interface StdControl;
}

implementation {
  components MainC, AccelP;
  MainC.SoftwareInit -> AccelP;
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

  components HplMM3AdcC;
  AccelP.HW -> HplMM3AdcC;

  components mm3ControlC;
  AccelP.mm3Control -> mm3ControlC.mm3Control[SNS_ID_ACCEL];

  components mm3CommDataC;
  AccelP.mm3CommData -> mm3CommDataC.mm3CommData[SNS_ID_ACCEL];
}
