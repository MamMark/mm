/*
 * Copyright (c) 2008, Eric B. Decker
 * All rights reserved.
 */

#include "sensors.h"

configuration PTempC {
  provides interface StdControl;
}
implementation {
  components MainC, PTempP;
  MainC.SoftwareInit -> PTempP;
  StdControl = PTempP;

  components RegimeC, new TimerMilliC() as PeriodTimer;
  PTempP.RegimeCtrl -> RegimeC.Regime;
  PTempP.PeriodTimer -> PeriodTimer;

  components AdcC;
  PTempP.Adc -> AdcC.Adc[SNS_ID_PTEMP];
  AdcC.SensorPowerControl[SNS_ID_PTEMP] -> PTempP;

  components AdcP;
  PTempP.AdcConfigure <- AdcP.Config[SNS_ID_PTEMP];

  components CollectC;
  PTempP.Collect -> CollectC;

  components HplMM3AdcC;
  PTempP.HW -> HplMM3AdcC;

  components mm3ControlC;
  PTempP.mm3Control -> mm3ControlC.mm3Control[SNS_ID_PTEMP];

  components mm3CommDataC;
  PTempP.mm3CommData -> mm3CommDataC.mm3CommData[SNS_ID_PTEMP];
}
