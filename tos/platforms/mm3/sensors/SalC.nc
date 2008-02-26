/*
 * Copyright (c) 2008, Eric B. Decker
 * All rights reserved.
 */

#include "sensors.h"

configuration SalC {
  provides interface StdControl;
}
implementation {
  components MainC, SalP;
  MainC.SoftwareInit -> SalP;
  StdControl = SalP;

  components RegimeC, new TimerMilliC() as PeriodTimer;
  SalP.RegimeCtrl -> RegimeC.Regime;
  SalP.PeriodTimer -> PeriodTimer;

  components AdcC;
  SalP.Adc -> AdcC.Adc[SNS_ID_SAL];

  components AdcP;
  SalP.AdcConfigure <- AdcP.Config[SNS_ID_SAL];

  components HplMM3AdcC;
  SalP.HW -> HplMM3AdcC;
}
