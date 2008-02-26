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

  components AdcP;
  PTempP.AdcConfigure <- AdcP.Config[SNS_ID_PTEMP];
}
