/*
 * Copyright (c) 2008, 2010, Eric B. Decker
 * All rights reserved.
 */

configuration TestSDArbC {}

implementation {
  components MainC, TestSDArbP;
  TestSDArbP -> MainC.Boot;

  components new SD_ArbC();
  TestSDArbP.Resource -> SD_ArbC;

  components new TimerMilliC() as T;
  TestSDArbP.Timer -> T;
}
