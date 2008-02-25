/* -*- mode:c; indent-tabs-mode: nil; c-basic-offset: 2 -*-
 * Copyright (c) 2008, Eric B. Decker
 * All rights reserved.
 */

#include "sensors.h"

configuration mm3MagC {
  provides interface StdControl;
}
implementation {
  components MainC, mm3MagP;
  MainC.SoftwareInit -> mm3MagP;
  StdControl = mm3MagP;

  components mm3RegimeC, new TimerMilliC() as PeriodTimer;
  mm3MagP.RegimeCtrl -> mm3RegimeC.mm3Regime;
  mm3MagP.PeriodTimer -> PeriodTimer;

  components mm3AdcC;
  mm3MagP.Adc -> mm3AdcC.mm3Adc[SNS_ID_MAG];

  components mm3AdcP;
  mm3MagP.AdcConfigure <- mm3AdcP.Config[SNS_ID_MAG];
}
