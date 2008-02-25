/* -*- mode:c; indent-tabs-mode: nil; c-basic-offset: 2 -*-
 * Copyright (c) 2008, Eric B. Decker
 * All rights reserved.
 */

#include "sensors.h"

configuration mm3PressC {
  provides interface StdControl;
}
implementation {
  components MainC, mm3PressP;
  MainC.SoftwareInit -> mm3PressP;
  StdControl = mm3PressP;

  components mm3RegimeC, new TimerMilliC() as PeriodTimer;
  mm3PressP.RegimeCtrl -> mm3RegimeC.mm3Regime;
  mm3PressP.PeriodTimer -> PeriodTimer;

  components mm3AdcC;
  mm3PressP.Adc -> mm3AdcC.mm3Adc[SNS_ID_PRESS];

  components mm3AdcP;
  mm3PressP.AdcConfigure <- mm3AdcP.Config[SNS_ID_PRESS];
}
