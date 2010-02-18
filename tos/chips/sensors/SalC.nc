/*
 * Copyright (c) 2008, 2010, Eric B. Decker
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
  AdcC.SensorPowerControl[SNS_ID_SAL] -> SalP;

  components AdcP;
  SalP.AdcConfigure <- AdcP.Config[SNS_ID_SAL];

  components CollectC;
  SalP.Collect -> CollectC;

  components Hpl_MM_hwC;
  SalP.HW -> Hpl_MM_hwC;

  components mmControlC;
  SalP.mmControl -> mmControlC.mmControl[SNS_ID_SAL];
  SalP.SenseVal <- mmControlC.SenseVal[SNS_ID_SAL];

  components mmCommDataC;
  SalP.mmCommData -> mmCommDataC.mmCommData[SNS_ID_SAL];

  components PanicC;
  SalP.Panic -> PanicC;
}
