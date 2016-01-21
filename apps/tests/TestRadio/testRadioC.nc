/*
 * Copyright (c) 2015 Eric B. Decker
 * All rights reserved.
 */

configuration testRadioC {}
implementation {
  components MainC, testRadioP;
  MainC.SoftwareInit -> testRadioP;
  testRadioP -> MainC.Boot;

  components new TimerMilliC() as Timer;
  testRadioP.testTimer -> Timer;

  components LocalTimeMilliC;
  testRadioP.LocalTime -> LocalTimeMilliC;

  components Si446xRadioC;

  components Si446xDriverLayerC;
  testRadioP.RadioState -> Si446xDriverLayerC;
  testRadioP.RadioSend -> Si446xDriverLayerC;
  testRadioP.RadioReceive -> Si446xDriverLayerC;

  components PanicC;
  testRadioP.Panic -> PanicC;
}
