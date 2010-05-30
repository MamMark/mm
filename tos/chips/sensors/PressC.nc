/*
 * Copyright (c) 2008, 2010, Eric B. Decker
 * All rights reserved.
 */

#include "sensors.h"

configuration PressC {
  provides interface StdControl;
}
implementation {
  components PressP;
  StdControl = PressP;

  components RegimeC, new TimerMilliC() as PeriodTimer;
  PressP.RegimeCtrl -> RegimeC.Regime;
  PressP.PeriodTimer -> PeriodTimer;

  components AdcC;
  PressP.Adc -> AdcC.Adc[SNS_ID_PRESS];
  AdcC.SensorPowerControl[SNS_ID_PRESS] -> PressP;

  components AdcP;
  PressP.AdcConfigure <- AdcP.Config[SNS_ID_PRESS];

  components CollectC;
  PressP.Collect -> CollectC;

  components Hpl_MM_hwC;
  PressP.HW -> Hpl_MM_hwC;

  components mmControlC;
  PressP.mmControl -> mmControlC.mmControl[SNS_ID_PRESS];

  components CommDTC;
  PressP.CommDT -> CommDTC.CommDT[SNS_ID_PRESS];

  components PanicC;
  PressP.Panic -> PanicC;
}
