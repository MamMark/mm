/*
 * Copyright (c) 2008, Eric B. Decker
 * All rights reserved.
 */

#include "sensors.h"

configuration PressC {
  provides interface StdControl;
}
implementation {
  components MainC, PressP;
  MainC.SoftwareInit -> PressP;
  StdControl = PressP;

  components RegimeC, new TimerMilliC() as PeriodTimer;
  PressP.RegimeCtrl -> RegimeC.Regime;
  PressP.PeriodTimer -> PeriodTimer;

  components AdcC;
  PressP.Adc -> AdcC.Adc[SNS_ID_PRESS];
  AdcC.SensorPowerControl[SNS_ID_PRESS] -> PressP;

  components AdcP;
  PressP.AdcConfigure <- AdcP.Config[SNS_ID_PRESS];

  components CollectC;
  PressP.Collect -> CollectC;

  components HplMM3AdcC;
  PressP.HW -> HplMM3AdcC;

  components mm3ControlC;
  PressP.mm3Control -> mm3ControlC.mm3Control[SNS_ID_PRESS];

  components mm3CommDataC;
  PressP.mm3CommData -> mm3CommDataC.mm3CommData[SNS_ID_PRESS];

  components PanicC;
  PressP.Panic -> PanicC;
}
