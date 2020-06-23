/*
 * Copyright (c) 2019, Eric B. Decker
 * All rights reserved.
 *
 * Accelerometer Sensor Head.
 * Wire in the head of the accel sensor code.
 *
 * AccelP code is a combination of a monitor which
 * collects single samples or can run autonomously
 * which uses accel chip interrupts to collect
 * multiple samples.
 */

configuration AccelC { }
implementation {
  components AccelP;
  components RegimeC, new TimerMilliC() as DrainTimerC;
  AccelP.RegimeCtrl -> RegimeC.Regime;
  AccelP.DrainTimer -> DrainTimerC;

  /* Accel Port */
  components Accel0C;
  AccelP.Accel    -> Accel0C;
  AccelP.AccelReg -> Accel0C;

  components CollectC;
  AccelP.Collect -> CollectC;

  components PanicC;
  AccelP.Panic -> PanicC;
}
