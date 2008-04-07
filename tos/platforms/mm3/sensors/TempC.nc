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
  AdcC.SensorPowerControl[SNS_ID_TEMP] -> TempP;

  components AdcP;
  TempP.AdcConfigure <- AdcP.Config[SNS_ID_TEMP];

  components CollectC;
  TempP.Collect -> CollectC;

  components HplMM3AdcC;
  TempP.HW -> HplMM3AdcC;

  components mm3ControlC;
  TempP.mm3Control -> mm3ControlC.mm3Control[SNS_ID_TEMP];

  components mm3CommDataC;
  TempP.mm3CommData -> mm3CommDataC.mm3CommData[SNS_ID_TEMP];
}
