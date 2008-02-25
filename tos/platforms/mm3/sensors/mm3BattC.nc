/* -*- mode:c; indent-tabs-mode: nil; c-basic-offset: 2 -*-
 * Copyright (c) 2008, Eric B. Decker
 * All rights reserved.
 */

#include "sensors.h"

configuration mm3BattC {
  provides interface StdControl;
}
implementation {
  components MainC, mm3BattP;
  MainC.SoftwareInit -> mm3BattP;
  StdControl = mm3BattP;

  components mm3RegimeC, new TimerMilliC() as PeriodTimer;
  mm3BattP.RegimeCtrl -> mm3RegimeC.mm3Regime;
  mm3BattP.PeriodTimer -> PeriodTimer;

  components mm3AdcC;
  mm3BattP.Adc -> mm3AdcC.mm3Adc[SNS_ID_BATT];

  components mm3AdcP;
  mm3BattP.AdcConfigure <- mm3AdcP.Config[SNS_ID_BATT];

  components mm3CollectC;
  mm3BattP.DC -> mm3CollectC;
}
