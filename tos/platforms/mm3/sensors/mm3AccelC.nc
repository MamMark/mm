/* -*- mode:c; indent-tabs-mode: nil; c-basic-offset: 2 -*-
 * Copyright (c) 2008, Eric B. Decker
 * All rights reserved.
 */

#include "sensors.h"

configuration mm3AccelC {
  provides interface StdControl;
}
implementation {
  components MainC, mm3AccelP;
  MainC.SoftwareInit -> mm3AccelP;
  StdControl = mm3AccelP;

  components mm3RegimeC, new TimerMilliC() as PeriodTimer;
  mm3AccelP.RegimeCtrl -> mm3RegimeC.mm3Regime;
  mm3AccelP.PeriodTimer -> PeriodTimer;

  components mm3AdcC;
  mm3AccelP.Adc -> mm3AdcC.mm3Adc[SNS_ID_ACCEL];

  components mm3AdcP;
  mm3AccelP.AdcConfigure <- mm3AdcP.Config[SNS_ID_ACCEL];
}
