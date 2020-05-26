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
}
