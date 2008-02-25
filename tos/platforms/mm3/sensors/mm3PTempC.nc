/* -*- mode:c; indent-tabs-mode: nil; c-basic-offset: 2 -*-
 * Copyright (c) 2008, Eric B. Decker
 * All rights reserved.
 */

#include "sensors.h"

configuration mm3PTempC {
  provides interface StdControl;
}
implementation {
  components MainC, mm3PTempP;
  MainC.SoftwareInit -> mm3PTempP;
  StdControl = mm3PTempP;

  components mm3RegimeC, new TimerMilliC() as PeriodTimer;
  mm3PTempP.RegimeCtrl -> mm3RegimeC.mm3Regime;
  mm3PTempP.PeriodTimer -> PeriodTimer;

  components mm3AdcC;
  mm3PTempP.Adc -> mm3AdcC.mm3Adc[SNS_ID_PTEMP];

  components mm3AdcP;
  mm3PTempP.AdcConfigure <- mm3AdcP.Config[SNS_ID_PTEMP];
}
