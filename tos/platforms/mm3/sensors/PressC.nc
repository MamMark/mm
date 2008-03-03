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

  components AdcP;
  PressP.AdcConfigure <- AdcP.Config[SNS_ID_PRESS];

  components CollectC;
  PressP.Collect -> CollectC;
}
