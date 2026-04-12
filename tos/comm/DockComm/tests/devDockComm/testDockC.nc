configuration testDockC { }
implementation {
  components testDockP, SystemBootC;
  testDockP.Boot -> SystemBootC.Boot;

  components PlatformC;
  testDockP.Platform   -> PlatformC;

  components new TimerMilliC() as Timer;
  testDockP.testTimer -> Timer;

  components LocalTimeMilliC;
  testDockP.LocalTime -> LocalTimeMilliC;

  components DockMonitorC, Dock0C;
  DockMonitorC.MsgTransmit -> Dock0C;
  DockMonitorC.MsgReceive  -> Dock0C;
}
