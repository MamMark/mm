/*
 * Copyright (c) 2008, Eric B. Decker
 * All rights reserved.
 */

#include "sensors.h"

configuration MagC {
  provides interface StdControl;
}

implementation {
  components MainC, MagP;
  MainC.SoftwareInit -> MagP;
  StdControl = MagP;

  components RegimeC, new TimerMilliC() as PeriodTimer;
  MagP.RegimeCtrl -> RegimeC.Regime;
  MagP.PeriodTimer -> PeriodTimer;

  components AdcC;
  MagP.Adc -> AdcC.Adc[SNS_ID_MAG];
  AdcC.SensorPowerControl[SNS_ID_MAG] -> MagP;

  components AdcP;
  MagP.AdcConfigure <- AdcP.Config[SNS_ID_MAG];

  components CollectC;
  MagP.Collect -> CollectC;

  components LedsC;
  MagP.Leds -> LedsC;
}
