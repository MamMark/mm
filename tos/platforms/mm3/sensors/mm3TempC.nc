/* -*- mode:c; indent-tabs-mode: nil; c-basic-offset: 2 -*-
 * Copyright (c) 2008, Eric B. Decker
 * All rights reserved.
 */

#include "sensors.h"

configuration mm3TempC {
  provides interface StdControl;
}
implementation {
  components MainC, mm3TempP;
  MainC.SoftwareInit -> mm3TempP;
  StdControl = mm3TempP;

  components mm3RegimeC, new TimerMilliC() as PeriodTimer;
  mm3TempP.RegimeCtrl -> mm3RegimeC.mm3Regime;
  mm3TempP.PeriodTimer -> PeriodTimer;

  components mm3AdcC;
  mm3TempP.Adc -> mm3AdcC.mm3Adc[SNS_ID_TEMP];

  components mm3AdcP;
  mm3TempP.AdcConfigure <- mm3AdcP.Config[SNS_ID_TEMP];
}
