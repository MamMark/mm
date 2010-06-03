/*
 * Copyright (c) 2008, 2010, Eric B. Decker
 * All rights reserved.
 */

#include "sensors.h"

configuration PTempC {
  provides interface StdControl;
}
implementation {
  components PTempP;
  StdControl = PTempP;

  components RegimeC, new TimerMilliC() as PeriodTimer;
  PTempP.RegimeCtrl -> RegimeC.Regime;
  PTempP.PeriodTimer -> PeriodTimer;

  components AdcC;
  PTempP.Adc -> AdcC.Adc[SNS_ID_PTEMP];
  AdcC.SensorPowerControl[SNS_ID_PTEMP] -> PTempP;

  components AdcP;
  PTempP.AdcConfigure <- AdcP.Config[SNS_ID_PTEMP];

  components CollectC;
  PTempP.Collect -> CollectC;

  components Hpl_MM_hwC;
  PTempP.HW -> Hpl_MM_hwC;

  components mmControlC;
  PTempP.mmControl -> mmControlC.mmControl[SNS_ID_PTEMP];

  components DTSenderC;
  PTempP.DTSender -> DTSenderC.DTSender[SNS_ID_PTEMP];

  components PanicC;
  PTempP.Panic -> PanicC;
}
