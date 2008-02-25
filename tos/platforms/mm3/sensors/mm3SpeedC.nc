/* -*- mode:c; indent-tabs-mode: nil; c-basic-offset: 2 -*-
 * Copyright (c) 2008, Eric B. Decker
 * All rights reserved.
 */

#include "sensors.h"

configuration mm3SpeedC {
  provides interface StdControl;
}
implementation {
  components MainC, mm3SpeedP;
  MainC.SoftwareInit -> mm3SpeedP;
  StdControl = mm3SpeedP;

  components mm3RegimeC, new TimerMilliC() as PeriodTimer;
  mm3SpeedP.RegimeCtrl -> mm3RegimeC.mm3Regime;
  mm3SpeedP.PeriodTimer -> PeriodTimer;

  components mm3AdcC;
  mm3SpeedP.Adc -> mm3AdcC.mm3Adc[SNS_ID_SPEED];

  components mm3AdcP;
  mm3SpeedP.AdcConfigure <- mm3AdcP.Config[SNS_ID_SPEED];
}
