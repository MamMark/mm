/* -*- mode:c; indent-tabs-mode: nil; c-basic-offset: 2 -*-
 * Copyright (c) 2008, Eric B. Decker
 * All rights reserved.
 */

#include "sensors.h"

configuration mm3SalC {
  provides interface StdControl;
}
implementation {
  components MainC, mm3SalP;
  MainC.SoftwareInit -> mm3SalP;
  StdControl = mm3SalP;

  components mm3RegimeC, new TimerMilliC() as PeriodTimer;
  mm3SalP.RegimeCtrl -> mm3RegimeC.mm3Regime;
  mm3SalP.PeriodTimer -> PeriodTimer;

  components mm3AdcC;
  mm3SalP.Adc -> mm3AdcC.mm3Adc[SNS_ID_SAL];

  components mm3AdcP;
  mm3SalP.AdcConfigure <- mm3AdcP.Config[SNS_ID_SAL];

  components HplMM3AdcC;
  mm3SalP.HW -> HplMM3AdcC;
}
